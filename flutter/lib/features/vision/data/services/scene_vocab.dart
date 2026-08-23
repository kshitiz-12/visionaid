/// Maps noisy ML Kit / Image Labeler / COCO names to words we can speak.
class SceneVocab {
  SceneVocab._();

  static const noise = {
    'screenshot',
    'font',
    'photograph',
    'photography',
    'snapshot',
    'macro photography',
    'flash photography',
    'magenta',
    'white',
    'black',
    'blue',
    'green',
    'red',
    'yellow',
    'pink',
    'pattern',
    'design',
    'art',
    'graphic design',
    'number',
    'text',
    'line',
    'rectangle',
    'circle',
  };

  static const _aliases = <String, String>{
    'headphones': 'headphones',
    'headphone': 'headphones',
    'headset': 'headphones',
    'earphones': 'headphones',
    'earphone': 'headphones',
    'earbuds': 'headphones',
    'earbud': 'headphones',
    'audio equipment': 'headphones',
    'notebook computer': 'laptop',
    'laptop computer': 'laptop',
    'laptop': 'laptop',
    'personal computer': 'laptop',
    'computer keyboard': 'keyboard',
    'keyboard': 'keyboard',
    'computer mouse': 'mouse',
    'cell phone': 'phone',
    'mobile phone': 'phone',
    'smart phone': 'phone',
    'smartphone': 'phone',
    'traffic light': 'traffic light',
    'stop sign': 'stop sign',
    'dining table': 'table',
    'coffee table': 'table',
    'potted plant': 'plant',
    'houseplant': 'plant',
    'people': 'person',
    'human': 'person',
    'pedestrian': 'person',
    'man': 'person',
    'woman': 'person',
    'crowd': 'people',
    'automobile': 'car',
    'motor vehicle': 'car',
    'land vehicle': 'car',
    'vehicle': 'car',
    'motorcycle': 'motorcycle',
    'staircase': 'stairs',
    'steps': 'stairs',
    'stair': 'stairs',
    'handbag': 'purse',
    'backpack': 'backpack',
    'suitcase': 'suitcase',
    'television': 'tv',
    'computer': 'laptop',
    'monitor': 'screen',
    'furniture': 'furniture',
    'couch': 'couch',
    'sofa': 'couch',
    'desk': 'table',
    'table': 'table',
    'chair': 'chair',
    'plant': 'plant',
    'tree': 'tree',
    'dog': 'dog',
    'cat': 'cat',
    'door': 'door',
    'window': 'window',
    'wall': 'wall',
    'brick wall': 'wall',
    'brick': 'wall',
    'interior design': 'wall',
    'building': 'building',
    'kitchen': 'kitchen',
    'street': 'street',
    'road': 'road',
    'purse': 'purse',
    'bag': 'purse',
    'phone': 'phone',
    'mouse': 'mouse',
    'book': 'book',
    'bottle': 'bottle',
    'cup': 'cup',
    'tv': 'tv',
    'person': 'person',
    'bicycle': 'bicycle',
    'bike': 'bicycle',
    'car': 'car',
    'bus': 'bus',
    'truck': 'truck',
    'indoors': 'indoors',
    'indoor': 'indoors',
    'money': 'money',
    'cash': 'money',
    'currency': 'money',
    'banknote': 'money',
    'bank note': 'money',
    'rupee': 'money',
    'rupees': 'money',
    'coin': 'money',
    'dollar bill': 'money',
    'paper money': 'money',
  };

  static String normalize(String raw) {
    var t = raw.trim().toLowerCase().replaceAll('_', ' ');
    if (t.isEmpty || t == 'object' || t == 'unknown' || noise.contains(t)) {
      return '';
    }
    if (_aliases.containsKey(t)) {
      return _aliases[t]!;
    }

    final keys = _aliases.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      if (t.contains(key)) {
        return _aliases[key]!;
      }
    }
    return t;
  }
}
