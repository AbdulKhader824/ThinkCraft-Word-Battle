"""Builds the word lists the app uses to check answers.

Every list comes from Wikidata, whose data is public domain (CC0), so the
app needs no credits screen for it. Downloads are kept in
build/word_sources/, so running the script again only re-cleans them; pass
--refresh to download again.

    py -3 tool/build_word_list.py            # build from the saved downloads
    py -3 tool/build_word_list.py --refresh  # download again, then build
    py -3 tool/build_word_list.py food brand # only these categories

It writes one file per category to assets/words/, one answer per line, in
a simple form: lower case, no accents, and only letters, digits and
single spaces. The app tidies the lines the same way again when loading,
so the exact matching rules live in one place: lib/services/rules/
word_check.dart.
"""

import glob
import hashlib
import io
import json
import os
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, 'build', 'word_sources')
OUT = os.path.join(ROOT, 'assets', 'words')
ENDPOINT = 'https://query.wikidata.org/sparql'
AGENT = 'PlayPalsWordListBuilder/1.0 (offline word game; build script)'

def chunked(query):
    """Splits a big query into 10, by the last digit of each item's id. A
    query that looks up an English name for tens of thousands of items is
    too slow for the free service in one go, but a tenth of it is fine."""
    return [
        query.replace('#CHUNK', 'FILTER(STRENDS(STR(?item), "%d"))' % digit)
        for digit in range(10)
    ]


# Each category is one or more queries. Every query returns ?name, an
# English name, and may return ?about, an English description used for
# filtering. Thresholds on sitelinks (how many Wikipedias have an article)
# keep the lists to things people have heard of.
# The two queries for one group of animals: common names, and labels of
# well-known ones (labels are often Latin, so only those count).
ANIMAL_TEMPLATES = [
    """SELECT DISTINCT ?name WHERE {
                  ?item wdt:P171* wd:%s ; wikibase:sitelinks ?links .
                  FILTER(?links >= 10)
                  ?item wdt:P1843 ?name . FILTER(lang(?name) = "en")
                }""",
    """SELECT DISTINCT ?name WHERE {
                  ?item wdt:P171* wd:%s ; wikibase:sitelinks ?links .
                  FILTER(?links >= 40)
                  ?item rdfs:label ?name . FILTER(lang(?name) = "en")
                }""",
]

QUERIES = {
    'animal': [
        # Animals, one group at a time, because all animals at once is too
        # big for the free service.
        *[
            query % group
            for query in ANIMAL_TEMPLATES
            # Mammals, birds, reptiles, amphibians, ray-finned fish,
            # sharks and rays, insects, arachnids, molluscs, crustaceans,
            # jellyfish and kin, starfish and kin, worms.
            for group in ['Q7377', 'Q5113', 'Q10811', 'Q10908', 'Q127282',
                          'Q25371', 'Q1390', 'Q1358', 'Q25326', 'Q25364',
                          'Q25441', 'Q44631', 'Q47253']
        ],
        # Breeds of dogs, cats, horses and the like.
        """SELECT DISTINCT ?name WHERE {
          VALUES ?kind { wd:Q39367 wd:Q43577 wd:Q1160573 wd:Q12045585
                         wd:Q15304943 }
          ?item wdt:P31 ?kind ; rdfs:label ?name .
          FILTER(lang(?name) = "en")
        }""",
    ],
    'bird': [
        # The same bird downloads Animal uses, plus chicken breeds.
        *[query % 'Q5113' for query in ANIMAL_TEMPLATES],
        """SELECT DISTINCT ?name WHERE {
          ?item wdt:P31 wd:Q15304943 ; rdfs:label ?name .
          FILTER(lang(?name) = "en")
        }""",
    ],
    'celebrity': [
        # Well-known actors, singers and sports stars, by full name.
        *chunked("""SELECT DISTINCT ?name WHERE {
          VALUES ?job { wd:Q33999 wd:Q10800557 wd:Q177220 wd:Q2643890
                        wd:Q12299841 wd:Q937857 wd:Q3665646 wd:Q10833314
                        wd:Q17125263 }
          ?item wdt:P106 ?job ; wikibase:sitelinks ?links .
          FILTER(?links >= 25)
          #CHUNK
          ?item rdfs:label ?name . FILTER(lang(?name) = "en")
        }"""),
    ],
    'cartoon': [
        # Animated and comic characters, and animated series.
        *chunked("""SELECT DISTINCT ?name ?about WHERE {
          VALUES ?kind { wd:Q15711870 wd:Q1114461 wd:Q581714 wd:Q117467246
                         wd:Q63952888 }
          ?item wdt:P31 ?kind ; wikibase:sitelinks ?links .
          FILTER(?links >= 3)
          #CHUNK
          ?item rdfs:label ?name . FILTER(lang(?name) = "en")
          OPTIONAL { ?item schema:description ?about .
                     FILTER(lang(?about) = "en") }
        }"""),
    ],
    'vegetable': [
        # Vegetables, leaf and root vegetables, and their kinds.
        """SELECT DISTINCT ?name WHERE {
          VALUES ?kind { wd:Q11004 wd:Q20134 wd:Q20136 }
          { ?item wdt:P31 ?kind } UNION { ?item wdt:P279+ ?kind }
          ?item wikibase:sitelinks ?links . FILTER(?links >= 3)
          ?item rdfs:label ?name . FILTER(lang(?name) = "en")
        }""",
    ],
    'flower': [
        # Flowers and ornamental plants.
        """SELECT DISTINCT ?name WHERE {
          VALUES ?kind { wd:Q506 wd:Q199182 }
          { ?item wdt:P31 ?kind } UNION { ?item wdt:P279+ ?kind }
          ?item rdfs:label ?name . FILTER(lang(?name) = "en")
        }""",
        # Flowering plants by common name were tried, but searching the
        # whole plant family tree is too slow for the free service; the
        # hand-written list covers everyday flowers.
    ],
    'vehicle': [
        # Kinds of vehicle, car models and motorcycle models.
        """SELECT DISTINCT ?name WHERE {
          ?item wdt:P279+ wd:Q42889 ; wikibase:sitelinks ?links .
          FILTER(?links >= 5)
          ?item rdfs:label ?name . FILTER(lang(?name) = "en")
        }""",
        *chunked("""SELECT DISTINCT ?name WHERE {
          VALUES ?kind { wd:Q3231690 wd:Q23866334 }
          ?item wdt:P31 ?kind ; wikibase:sitelinks ?links .
          FILTER(?links >= 5)
          #CHUNK
          ?item rdfs:label ?name . FILTER(lang(?name) = "en")
        }"""),
    ],
    'sport': [
        # Sports and kinds of sport.
        """SELECT DISTINCT ?name ?about WHERE {
          VALUES ?kind { wd:Q349 wd:Q31629 }
          { ?item wdt:P31 ?kind } UNION { ?item wdt:P279+ ?kind }
          ?item wikibase:sitelinks ?links . FILTER(?links >= 3)
          ?item rdfs:label ?name . FILTER(lang(?name) = "en")
          OPTIONAL { ?item schema:description ?about .
                     FILTER(lang(?about) = "en") }
        }""",
    ],
    'game': [
        # Well-known video games.
        *chunked("""SELECT DISTINCT ?name ?about WHERE {
          ?item wdt:P31 wd:Q7889 ; wikibase:sitelinks ?links .
          FILTER(?links >= 15)
          #CHUNK
          ?item rdfs:label ?name . FILTER(lang(?name) = "en")
          OPTIONAL { ?item schema:description ?about .
                     FILTER(lang(?about) = "en") }
        }"""),
        # Board, card and children's games.
        """SELECT DISTINCT ?name ?about WHERE {
          VALUES ?kind { wd:Q131436 wd:Q142714 wd:Q1509934 }
          ?item wdt:P31 ?kind ; rdfs:label ?name .
          FILTER(lang(?name) = "en")
          OPTIONAL { ?item schema:description ?about .
                     FILTER(lang(?about) = "en") }
        }""",
    ],
    'place': [
        # Countries.
        """SELECT DISTINCT ?name WHERE {
          VALUES ?kind { wd:Q6256 wd:Q3624078 }
          ?item wdt:P31 ?kind ; rdfs:label ?name .
          FILTER(lang(?name) = "en")
        }""",
        # Cities, towns, states and regions with 50,000 or more people.
        *chunked("""SELECT DISTINCT ?name WHERE {
          ?item wdt:P1082 ?people . FILTER(?people >= 50000)
          #CHUNK
          ?item wdt:P625 [] ; rdfs:label ?name . FILTER(lang(?name) = "en")
        }"""),
        # Well-known places without a population: continents, oceans,
        # rivers, mountains, islands, deserts, lakes and seas.
        *chunked("""SELECT DISTINCT ?name WHERE {
          VALUES ?kind { wd:Q5107 wd:Q9430 wd:Q4022 wd:Q8502 wd:Q23442
                         wd:Q8514 wd:Q23397 wd:Q165 wd:Q46831 }
          ?item wdt:P31 ?kind ; wikibase:sitelinks ?links .
          FILTER(?links >= 15)
          #CHUNK
          ?item rdfs:label ?name . FILTER(lang(?name) = "en")
        }"""),
    ],
    'person': [
        # First names, from every part of the world: male, female, unisex
        # and other given names.
        *[
            part
            for kind in ['Q12308941', 'Q11879590', 'Q3409032', 'Q202444']
            for part in chunked("""SELECT DISTINCT ?name WHERE {
              ?item wdt:P31 wd:%s .
              #CHUNK
              ?item rdfs:label ?name . FILTER(lang(?name) = "en")
            }""" % kind)
        ],
        # Family names that are fairly common.
        *chunked("""SELECT DISTINCT ?name WHERE {
          ?item wdt:P31 wd:Q101352 ; wikibase:sitelinks ?links .
          FILTER(?links >= 3)
          #CHUNK
          ?item rdfs:label ?name . FILTER(lang(?name) = "en")
        }"""),
        # Famous people by full name were tried, but searching every person
        # on Wikidata is too slow for the free service. First and family
        # names cover what players type.
    ],
    'movie': [
        # Well-known films, with their descriptions for filtering.
        """SELECT DISTINCT ?name ?about WHERE {
          ?item wdt:P31 wd:Q11424 ; wikibase:sitelinks ?links ;
                rdfs:label ?name .
          FILTER(?links >= 12 && lang(?name) = "en")
          OPTIONAL { ?item schema:description ?about .
                     FILTER(lang(?about) = "en") }
        }""",
        # Indian films, which have fewer Wikipedia articles abroad.
        """SELECT DISTINCT ?name ?about WHERE {
          ?item wdt:P31 wd:Q11424 ; wdt:P495 wd:Q668 ;
                wikibase:sitelinks ?links ; rdfs:label ?name .
          FILTER(?links >= 3 && lang(?name) = "en")
          OPTIONAL { ?item schema:description ?about .
                     FILTER(lang(?about) = "en") }
        }""",
        # Animated films, which children know best.
        """SELECT DISTINCT ?name ?about WHERE {
          ?item wdt:P31 wd:Q202866 ; wikibase:sitelinks ?links ;
                rdfs:label ?name .
          FILTER(?links >= 5 && lang(?name) = "en")
          OPTIONAL { ?item schema:description ?about .
                     FILTER(lang(?about) = "en") }
        }""",
    ],
    'food': [
        # Foods, dishes, fruits, vegetables, sweets, breads and cheeses.
        """SELECT DISTINCT ?name ?about WHERE {
          VALUES ?kind { wd:Q2095 wd:Q746549 wd:Q1364 wd:Q11004 wd:Q2920963
                         wd:Q7802 wd:Q10943 wd:Q13360264 wd:Q178 wd:Q40050
                         wd:Q182940 wd:Q5159627 wd:Q41415 wd:Q749316
                         wd:Q42527 wd:Q11009 wd:Q8495 wd:Q3314483
                         wd:Q19861951 }
          { ?item wdt:P31 ?kind } UNION { ?item wdt:P279 ?kind }
          ?item wikibase:sitelinks ?links ; rdfs:label ?name .
          FILTER(?links >= 4 && lang(?name) = "en")
          OPTIONAL { ?item schema:description ?about .
                     FILTER(lang(?about) = "en") }
        }""",
        # Anything that is a kind of food, however indirectly (pizza is a
        # flatbread dish, which is a food), if it is fairly well known.
        """SELECT DISTINCT ?name ?about WHERE {
          ?item wdt:P279+ wd:Q2095 ; wikibase:sitelinks ?links .
          FILTER(?links >= 15)
          ?item rdfs:label ?name . FILTER(lang(?name) = "en")
          OPTIONAL { ?item schema:description ?about .
                     FILTER(lang(?about) = "en") }
        }""",
        # Indian dishes.
        """SELECT DISTINCT ?name ?about WHERE {
          ?item wdt:P31 wd:Q746549 ; wdt:P495 wd:Q668 ; rdfs:label ?name .
          FILTER(lang(?name) = "en")
          OPTIONAL { ?item schema:description ?about .
                     FILTER(lang(?about) = "en") }
        }""",
    ],
    # Things are too varied to ask Wikidata for, so this list is only the
    # hand-written one in tool/core_words/thing.txt.
    'thing': [],
    'brand': [
        # Brands, including food brands.
        """SELECT DISTINCT ?name ?about WHERE {
          VALUES ?kind { wd:Q431289 wd:Q16323605 }
          ?item wdt:P31 ?kind ; wikibase:sitelinks ?links ;
                rdfs:label ?name .
          FILTER(?links >= 3 && lang(?name) = "en")
          OPTIONAL { ?item schema:description ?about .
                     FILTER(lang(?about) = "en") }
        }""",
        # Well-known companies, whose names are their brands.
        *chunked("""SELECT DISTINCT ?name ?about WHERE {
          VALUES ?kind { wd:Q4830453 wd:Q891723 wd:Q6881511 wd:Q783794
                         wd:Q210167 wd:Q1058914 wd:Q507619 wd:Q18534542 }
          ?item wdt:P31 ?kind ; wikibase:sitelinks ?links .
          FILTER(?links >= 15)
          #CHUNK
          ?item rdfs:label ?name . FILTER(lang(?name) = "en")
          OPTIONAL { ?item schema:description ?about .
                     FILTER(lang(?about) = "en") }
        }"""),
    ],
}

# Anything described with these words stays out: the app is for children.
# Films and brands are filtered by their description, every list by name.
BLOCKED_TOPICS = re.compile(
    r'\b(porn\w*|pornograph\w*|erotic\w*|sex\w*|adult film|hentai|nud\w*|'
    r'beer|brew\w*|wine\w*|winery|whisk(e)?y|vodka|gin|rum|tequila|'
    r'liquor|spirits|champagne|alcohol\w*|distiller\w*|cider|sake|'
    r'tobacco|cigar\w*|vap(e|ing)|cannabis|marijuana|drug cartel|'
    r'casino\w*|gambling|betting|bookmaker|lottery|weapon\w*|firearm\w*|'
    r'gun\w*|pistol\w*|rifle\w*|ammunition)\b',
    re.IGNORECASE,
)

# Rude words never count as an answer, even as part of one.
RUDE = {
    'arse', 'ass', 'asshole', 'bastard', 'bitch', 'bollocks', 'boob',
    'boobs', 'cock', 'crap', 'cunt', 'damn', 'dick', 'dildo', 'fag',
    'faggot', 'fuck', 'fucker', 'fucking', 'hell', 'horny', 'jerk',
    'milf', 'nazi', 'nigga', 'nigger', 'penis', 'piss', 'porn', 'prick',
    'pussy', 'rape', 'retard', 'sex', 'sexy', 'shit', 'slut', 'tit',
    'tits', 'twat', 'vagina', 'wank', 'wanker', 'whore', 'xxx',
}

# Wikidata labels that are really identifiers or disambiguation, not names.
NOT_A_NAME = re.compile(r'^(q\d+|list of .*|.* \(.*\))$')


def simple(text):
    """The plain form written to the files."""
    text = unicodedata.normalize('NFKD', text)
    text = ''.join(c for c in text if not unicodedata.combining(c))
    text = text.lower().replace('&', ' and ')
    text = re.sub(r"['’]", '', text)
    text = re.sub(r'[^a-z0-9]+', ' ', text).strip()
    if text.startswith('the '):
        text = text[4:]
    return text


def read_literal(cell):
    """Reads one tab-separated cell, like "Banana"@en, as plain text."""
    if not cell:
        return ''
    if not cell.startswith('"'):
        raise ValueError('not a text value: %r' % cell[:40])
    text = cell[1:cell.rindex('"')]
    escapes = {'t': '\t', 'n': '\n', 'r': '\r', '"': '"', '\\': '\\'}
    return re.sub(r'\\(.)', lambda m: escapes.get(m.group(1), m.group(1)), text)


def read_tsv(text):
    """Reads the service's tab-separated answer. A reply cut off by the
    time limit ends in an error report instead of rows, so it is refused
    rather than half used."""
    lines = text.split('\n')
    header = [name.lstrip('?') for name in lines[0].split('\t')]
    rows = []
    for line in lines[1:]:
        if not line:
            continue
        if not line.startswith('"'):
            raise ValueError('cut off: %r' % line[:40])
        cells = dict(zip(header, line.split('\t')))
        rows.append({
            'name': read_literal(cells.get('name', '')),
            'about': read_literal(cells.get('about', '')),
        })
    return rows


def fetch(category, index, query):
    # Named after the query, so changing one query only re-downloads it.
    digest = hashlib.sha1(query.encode('utf-8')).hexdigest()[:12]
    path = os.path.join(CACHE, '%s_%s.json' % (category, digest))
    if '--refresh' not in sys.argv:
        # Another category may have saved the very same query (Bird and
        # Animal share their bird downloads).
        saved = glob.glob(os.path.join(CACHE, '*_%s.json' % digest))
        if saved:
            with io.open(saved[0], encoding='utf-8') as f:
                return json.load(f)

    print('  downloading %s, part %d...' % (category, index + 1), flush=True)
    # Tab-separated text is about five times smaller than JSON, so big
    # answers arrive before the service's 60-second limit.
    body = urllib.parse.urlencode({'query': query})
    request = urllib.request.Request(
        ENDPOINT,
        data=body.encode('utf-8'),
        headers={'User-Agent': AGENT, 'Accept': 'text/tab-separated-values'},
    )
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                rows = read_tsv(response.read().decode('utf-8'))
            break
        except Exception as error:  # A busy server: wait and try again.
            print('    failed (%s), trying again...' % str(error)[:80])
            time.sleep(20 * (attempt + 1))
    else:
        # Skipped, not fatal: the list is still useful without one part,
        # and running the script again tries the missing parts once more.
        print('    SKIPPED %s, part %d: the service is busy. Run the script '
              'again later to fill it in.' % (category, index + 1))
        return []

    os.makedirs(CACHE, exist_ok=True)
    with io.open(path, 'w', encoding='utf-8') as f:
        json.dump(rows, f, ensure_ascii=False)
    time.sleep(2)  # Be gentle with the free service.
    return rows


# Categories whose names are checked for blocked topics too. Names of
# people and places aren't: "Gunnar" and "Brewster" are fine.
TOPIC_CHECKED_NAMES = {'movie', 'brand', 'food', 'cartoon', 'game',
                       'sport', 'thing', 'vehicle', 'vegetable', 'flower'}


def keep(category, name, about):
    if NOT_A_NAME.match(name.lower()):
        return False
    if BLOCKED_TOPICS.search(about):
        return False
    if category in TOPIC_CHECKED_NAMES and BLOCKED_TOPICS.search(name):
        return False
    words = simple(name).split()
    if not words or any(word in RUDE for word in words):
        return False
    # Answers are typed on a phone, so very long names are left out.
    return len(simple(name)) <= 40 and words[0][0].isalpha()


def core_words(category):
    """Everyday answers written by hand, in tool/core_words/. Wikidata
    files some of the commonest things in ways the queries miss (a dog is
    recorded as a kind of wolf, not as an animal species), so these make
    sure the answers children type most are always known."""
    path = os.path.join(ROOT, 'tool', 'core_words', category + '.txt')
    if not os.path.exists(path):
        return []
    with io.open(path, encoding='utf-8') as f:
        return [line.strip() for line in f
                if line.strip() and not line.startswith('#')]


def main():
    os.makedirs(OUT, exist_ok=True)
    chosen = [arg for arg in sys.argv[1:] if not arg.startswith('--')]
    unknown = set(chosen) - set(QUERIES)
    if unknown:
        sys.exit('No such category: %s' % ', '.join(sorted(unknown)))
    for category, queries in QUERIES.items():
        if chosen and category not in chosen:
            continue
        print(category, flush=True)
        words = set()
        for index, query in enumerate(queries):
            for row in fetch(category, index, query):
                if keep(category, row['name'], row['about']):
                    words.add(simple(row['name']))
        for word in core_words(category):
            words.add(simple(word))
        path = os.path.join(OUT, category + '.txt')
        with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(sorted(words)) + '\n')
        print('  %d answers' % len(words), flush=True)


if __name__ == '__main__':
    main()
