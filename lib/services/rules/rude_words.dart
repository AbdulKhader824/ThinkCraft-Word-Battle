/// Letters that spell something rude, even inside a real word (a pickle
/// called "shitakusa").
final _rude = RegExp(
  'shit|fuck|cunt|porn|sex|nigg|dick|cock|slut|whore|rape|bitch|piss|'
  'tits|penis|anal|wank|twat|crap|boob|nazi',
);

/// True when [text] has something rude in it, in any capitals.
bool soundsRude(String text) => _rude.hasMatch(text.toLowerCase());
