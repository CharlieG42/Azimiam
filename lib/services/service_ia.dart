import 'dart:convert';

import 'package:http/http.dart' as http;

/// Erreur métier de la couche IA.
class AiException implements Exception {
  final String message;
  const AiException(this.message);

  @override
  String toString() => message;
}

/// Un aliment reconnu par l'IA sur la photo.
class AnalyseIa {
  final String nom;
  final double grammes;
  final double confiance;

  const AnalyseIa({
    required this.nom,
    required this.grammes,
    required this.confiance,
  });
}

/// Couche IA : appel d'un modèle de vision multimodal (Mistral Pixtral par
/// défaut, tout endpoint compatible « OpenAI chat completions » convient).
///
/// L'IA IDENTIFIE les aliments et estime les quantités ; elle ne fournit
/// JAMAIS les valeurs nutritionnelles : celles-ci viennent de la base
/// locale (voir ServiceNutrition). C'est le cœur du design d'Azimiam.
class ServiceIa {
  final String cleApi;
  final String baseUrl;
  final String modele;

  const ServiceIa({
    required this.cleApi,
    this.baseUrl = 'https://api.mistral.ai/v1',
    this.modele = 'pixtral-12b-2409',
  });

  static const String prompt = '''
Tu es un expert en nutrition. Analyse la photo de ce repas.
1. Identifie chaque aliment ou boisson visible, y compris les sauces et matières grasses apparentes.
2. Estime la quantité de chacun en grammes. Repères : assiette ≈ 26 cm de diamètre, fourchette ≈ 20 cm, canette ≈ 330 ml, tranche de pain ≈ 40 g, steak ≈ 150 g.
3. Réponds UNIQUEMENT par un tableau JSON valide, sans aucun texte autour, au format exact :
[{"nom": "Poulet grillé", "grammes": 150, "confiance": 0.8}]
- "nom" : nom français COURT et SIMPLE, 1 à 4 mots max, SANS parenthèses ni descriptions. Si le plat est un classique nommé, donne directement son nom (ex. « Lasagne », « Quiche lorraine », « Couscous », « Gratin dauphinois ») avec sa quantité totale ; sinon, décompose en composants simples (« Poulet grillé », « Riz blanc », « Haricots verts »). Bannis les tournures comme « Biscuit sec type petit-beurre » ou « Crème pâtissière ou crème dessert » : écris « Biscuit », « Crème dessert ».
- "grammes" : nombre (les boissons aussi, en grammes ≈ millilitres).
- "confiance" : nombre entre 0 et 1 (0 = très incertain).
''';

  /// Analyse les octets JPEG/PNG de la photo et renvoie les aliments détectés.
  Future<List<AnalyseIa>> analyserPhoto(List<int> octetsImage) async {
    final imageBase64 = base64Encode(octetsImage);
    final reponse = await http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $cleApi',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': modele,
        'temperature': 0.2,
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
              },
            ],
          },
        ],
      }),
    );

    if (reponse.statusCode != 200) {
      var detail = utf8.decode(reponse.bodyBytes);
      if (detail.length > 300) detail = detail.substring(0, 300);
      throw AiException('API $modele (HTTP ${reponse.statusCode}) : $detail');
    }

    final data = jsonDecode(utf8.decode(reponse.bodyBytes));
    final contenu = data['choices'][0]['message']['content'] as String? ?? '';
    return parseJsonItems(contenu);
  }

  /// Extrait la liste d'aliments d'une réponse texte du modèle.
  ///
  /// Tolérant : gère les fences markdown, le texte autour du JSON,
  /// un objet englobant, et les variantes de noms de champs.
  static List<AnalyseIa> parseJsonItems(String contenu) {
    var texte = contenu.trim();

    // Retire les fences markdown éventuelles.
    if (texte.startsWith('```')) {
      texte = texte.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      final finFence = texte.lastIndexOf('```');
      if (finFence != -1) texte = texte.substring(0, finFence);
    }

    dynamic racine;
    if (texte.contains('[')) {
      final debut = texte.indexOf('[');
      final fin = texte.lastIndexOf(']');
      if (fin <= debut) throw const FormatException('Tableau JSON invalide');
      racine = jsonDecode(texte.substring(debut, fin + 1));
    } else if (texte.contains('{')) {
      // Objet seul : soit une liste embarquée, soit un aliment unique.
      final debut = texte.indexOf('{');
      final fin = texte.lastIndexOf('}');
      racine = jsonDecode(texte.substring(debut, fin + 1));
      if (racine is Map) {
        for (final valeur in racine.values) {
          if (valeur is List) {
            racine = valeur;
            break;
          }
        }
      }
    } else {
      throw const FormatException('Aucun JSON trouvé dans la réponse IA');
    }

    if (racine is! List) {
      if (racine is Map) {
        racine = [racine];
      } else {
        throw const FormatException('JSON IA inattendu');
      }
    }

    final resultats = <AnalyseIa>[];
    for (final element in racine) {
      if (element is! Map) continue;
      final champs = element
          .map((cle, valeur) => MapEntry(cle.toString().toLowerCase(), valeur));

      final nomBrut = champs['nom'] ??
          champs['aliment'] ??
          champs['name'] ??
          champs['food'] ??
          '';
      final nom = nomBrut.toString().trim();
      if (nom.isEmpty) continue;

      final grammes = _versDouble(
        champs['grammes'] ??
            champs['gram'] ??
            champs['quantite_g'] ??
            champs['quantite'] ??
            champs['quantity_g'] ??
            champs['quantity'] ??
            champs['portion_g'] ??
            0,
      );
      if (grammes <= 0) continue;

      var confiance =
          _versDouble(champs['confiance'] ?? champs['confidence'] ?? 0.5);
      if (confiance < 0) confiance = 0;
      if (confiance > 1) confiance = 1;

      resultats
          .add(AnalyseIa(nom: nom, grammes: grammes, confiance: confiance));
    }
    return resultats;
  }

  static double _versDouble(dynamic valeur) {
    if (valeur is num) return valeur.toDouble();
    if (valeur is String) {
      final match = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(valeur);
      if (match == null) return 0;
      return double.tryParse(match.group(0)!.replaceAll(',', '.')) ?? 0;
    }
    return 0;
  }

  /// Traduit une erreur de l'appel IA en message compréhensible : les
  /// exceptions réseau brutes (« Failed host lookup … errno = 7 ») n'ont
  /// aucun sens pour l'utilisateur et ressemblent à un bug du modèle.
  static String messageErreur(Object erreur, {String? baseUrl}) {
    final texte = erreur.toString();
    if (texte.contains('Failed host lookup') ||
        texte.contains('SocketException') ||
        texte.contains('Connection refused') ||
        texte.contains('Connection timed out') ||
        texte.contains('Network is unreachable') ||
        texte.contains('Connection closed') ||
        texte.contains('Software caused connection abort') ||
        texte.contains('Failed to parse URL')) {
      final hote = baseUrl ?? '';
      return 'Pas de connexion à Internet : impossible de joindre '
          '${hote.isEmpty ? 'l\'API Mistral' : hote}. '
          'Vérifiez le réseau de votre téléphone (Wi-Fi, données mobiles, '
          'DNS privé) puis réessayez. Ce n\'est pas un problème de modèle '
          'ni de clé API.';
    }
    return 'Analyse IA échouée : $texte';
  }
}
