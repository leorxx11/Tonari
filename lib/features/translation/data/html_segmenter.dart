import 'dart:math' as math;

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class HtmlSegments {
  HtmlSegments({
    required this.fragment,
    required this.nodes,
    required this.texts,
  });

  final dom.DocumentFragment fragment;
  final List<dom.Text> nodes;
  final List<String> texts;
}

class HtmlSegmenter {
  static HtmlSegments segment(String html) {
    final fragment = html_parser.parseFragment(html);
    final nodes = <dom.Text>[];
    final texts = <String>[];

    void walk(dom.Node node) {
      if (node is dom.Text) {
        if (node.text.trim().isEmpty) return;
        nodes.add(node);
        texts.add(node.text);
        return;
      }
      if (node is! dom.Element) return;
      final tag = node.localName;
      if (tag == 'script' || tag == 'style') return;
      for (final c in node.nodes) {
        walk(c);
      }
    }

    for (final n in fragment.nodes) {
      walk(n);
    }
    return HtmlSegments(fragment: fragment, nodes: nodes, texts: texts);
  }

  static String fill(HtmlSegments segments, List<String> translated) {
    final n = math.min(segments.nodes.length, translated.length);
    for (var i = 0; i < n; i++) {
      segments.nodes[i].text = translated[i];
    }
    return segments.fragment.outerHtml;
  }
}
