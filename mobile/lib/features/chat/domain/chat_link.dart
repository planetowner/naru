final RegExp chatUrlPattern = RegExp(
  r'''(?:(?:https?):\/\/|www\.)[^\s<>'"]+''',
  caseSensitive: false,
);

const String chatTrailingUrlPunctuation = '.,!?;:)]}…';

String? firstChatUrlInText(String content) {
  return chatUrlsInText(content).firstOrNull;
}

Iterable<String> chatUrlsInText(String content) sync* {
  final Set<String> seen = <String>{};
  for (final RegExpMatch match in chatUrlPattern.allMatches(content)) {
    String url = match.group(0)!.trimRight();
    while (url.isNotEmpty &&
        chatTrailingUrlPunctuation.contains(url[url.length - 1])) {
      url = url.substring(0, url.length - 1);
    }
    if (url.toLowerCase().startsWith('www.')) url = 'https://$url';
    if (seen.add(url)) yield url;
  }
}

String chatDomainForUrl(String url) {
  String domain = Uri.tryParse(url)?.host ?? '';
  if (domain.isEmpty) {
    return url;
  }

  if (domain.startsWith('www.')) {
    domain = domain.substring(4);
  }

  return domain;
}
