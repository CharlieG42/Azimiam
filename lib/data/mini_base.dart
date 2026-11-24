import '../models/valeurs.dart';

/// Un aliment de la base locale.
class Aliment {
  /// Nom affiché (et reconnu par la recherche).
  final String nom;

  /// Variantes/noms proches qui remontent aussi à la recherche.
  final List<String> alias;

  final ValeursNutritionnelles valeurs;

  /// Vrai si l'aliment a été ajouté par l'utilisateur au catalogue
  /// (table `aliments_perso`) : il peut être supprimé.
  final bool perso;

  /// Identifiant en base (aliments personnalisés uniquement).
  final int? id;

  Aliment(this.nom, this.alias, this.valeurs, {this.perso = false, this.id});
}

/// Mini-base locale d'aliments courants (~110), valeurs APPROXIMATIVES
/// pour 100 g inspirées de la table CIQUAL (ANSES).
///
/// ⚠️ Ces valeurs sont une version raccourcie pour le prototype : la
/// roadmap prévoit l'import complet de CIQUAL (open data) pour couvrir
/// ~2 750 aliments avec les valeurs officielles, fibres, sucres, sels
/// et micronutriments.
class BaseAliments {
  static ValeursNutritionnelles v(
    double kcal,
    double proteines,
    double glucides,
    double lipides, {
    double fibres = 0,
    double sucres = 0,
    double sel = 0,
  }) =>
      ValeursNutritionnelles(
        kcal: kcal,
        proteines: proteines,
        glucides: glucides,
        lipides: lipides,
        fibres: fibres,
        sucres: sucres,
        sel: sel,
      );

  static final List<Aliment> tous = <Aliment>[
    // ---- Viandes, poissons, œufs ----
    Aliment(
        'Poulet grillé',
        ['poulet', 'blanc de poulet', 'volaille', 'chicken'],
        v(165, 31, 0, 3.6)),
    Aliment('Steak de bœuf grillé',
        ['boeuf', 'steak', 'entrecote', 'steak de boeuf'], v(250, 26, 0, 15)),
    Aliment('Steak haché 5 %', ['viande hachee', 'hache', 'steak hache'],
        v(145, 21, 0, 5)),
    Aliment('Filet de porc', ['porc', 'filet mignon', 'porc grillé'],
        v(143, 26, 0, 3.5)),
    Aliment('Côtelette d\'agneau', ['agneau', 'gigot', 'cotelette'],
        v(250, 25, 0, 17)),
    Aliment('Escalope de veau', ['veau', 'escalope', 'escalope de veau'],
        v(172, 24, 0, 8)),
    Aliment(
        'Saucisse',
        ['saucisses', 'merguez', 'chipolatas', 'saucisse de toulouse'],
        v(300, 12, 2, 28)),
    Aliment('Jambon blanc', ['jambon', 'tranche de jambon', 'jambon blanc'],
        v(108, 17, 1, 4, sel: 2.5)),
    Aliment('Lardons fumés', ['lardons', 'lard', 'bacon'], v(400, 10, 0, 40)),
    Aliment('Thon frais', ['thon', 'steak de thon', 'thon rouge'],
        v(130, 28, 0, 1)),
    Aliment(
        'Thon en boîte à l\'eau',
        ['thon en conserve', 'thon a l eau', 'boite de thon'],
        v(116, 26, 0, 1)),
    Aliment('Saumon cuit', ['saumon', 'pave de saumon', 'saumon fume'],
        v(208, 20, 0, 13)),
    Aliment('Cabillaud', ['cabillaud', 'morue', 'colin', 'poisson blanc'],
        v(82, 18, 0, 0.7)),
    Aliment(
        'Crevettes',
        ['crevette', 'gambas', 'langoustines', 'fruits de mer'],
        v(99, 21, 0, 1)),
    Aliment('Moules cuites', ['moules', 'moules mariniere'], v(86, 12, 3, 2)),
    Aliment(
        'Œuf cuit',
        ['oeuf', 'oeufs', 'omelette', 'oeuf au plat', 'oeuf dur'],
        v(155, 13, 1, 11)),

    // ---- Féculents ----
    Aliment('Riz blanc cuit', ['riz', 'riz blanc', 'riz cuit'],
        v(130, 2.7, 28, 0.3, fibres: 0.4)),
    Aliment('Riz complet cuit', ['riz complet', 'riz brun'],
        v(123, 2.6, 26, 1, fibres: 1.8)),
    Aliment(
        'Pâtes cuites',
        ['pates', 'spaghetti', 'penne', 'tagliatelles', 'noodles'],
        v(131, 5, 25, 1.1, fibres: 1.8)),
    Aliment(
        'Pommes de terre cuites',
        ['pomme de terre', 'patates', 'pommes de terre', 'pdt'],
        v(87, 2, 20, 0.1, fibres: 1.8)),
    Aliment('Purée de pommes de terre', ['puree', 'puree de pommes de terre'],
        v(100, 2, 15, 4)),
    Aliment('Frites', ['frites', 'potatoes'], v(312, 3.4, 41, 15)),
    Aliment('Pain de mie', ['pain de mie', 'toast', 'tartine'],
        v(265, 9, 49, 3.2, fibres: 2.7, sucres: 2.6, sel: 1.2)),
    Aliment('Baguette', ['baguette', 'pain', 'tradition', 'pain blanc'],
        v(275, 9, 52, 2.5, fibres: 2.5, sel: 1.3)),
    Aliment(
        'Pain complet',
        ['pain complet', 'pain aux cereales', 'pain de seigle'],
        v(248, 10, 41, 3.4, fibres: 6, sel: 1.1)),
    Aliment('Semoule cuite', ['semoule', 'couscous', 'graine de couscous'],
        v(112, 3.8, 23, 0.2)),
    Aliment('Quinoa cuit', ['quinoa'], v(120, 4.4, 21, 1.9, fibres: 2.8)),
    Aliment('Lentilles cuites', ['lentilles', 'dahl', 'lentilles vertes'],
        v(116, 9, 20, 0.4, fibres: 8)),
    Aliment('Haricots rouges cuits', ['haricots rouges', 'haricots', 'beans'],
        v(127, 8.7, 22.8, 0.5, fibres: 6.4)),
    Aliment('Pois chiches cuits', ['pois chiches', 'chickpeas'],
        v(164, 8.9, 27, 2.6, fibres: 7.6)),
    Aliment('Tortilla de blé', ['tortilla', 'galette', 'wrap', 'taco'],
        v(300, 8, 50, 7)),
    Aliment(
        'Boulgour cuit', ['boulgour', 'ebly'], v(83, 3, 19, 0.2, fibres: 4.5)),
    Aliment('Croissant', ['croissants', 'viennoiserie', 'pain au lait'],
        v(406, 8, 46, 21, sucres: 5)),

    // ---- Légumes ----
    Aliment('Brocoli cuit', ['brocoli', 'brocolis'],
        v(35, 2.4, 7, 0.4, fibres: 3.3)),
    Aliment('Carottes crues', ['carotte', 'carottes'],
        v(36, 0.9, 8, 0.2, fibres: 2.4, sucres: 4.7)),
    Aliment('Tomate', ['tomate', 'tomates', 'tomates cerises'],
        v(18, 0.9, 3.9, 0.2, fibres: 1.2, sucres: 2.6)),
    Aliment(
        'Salade verte',
        ['salade', 'laitue', 'mesclun', 'roquette', 'salade verte'],
        v(15, 1.4, 2, 0.2, fibres: 1)),
    Aliment('Épinards cuits', ['epinard', 'epinards'],
        v(23, 2.9, 3.6, 0.4, fibres: 2)),
    Aliment('Haricots verts cuits', ['haricots verts'],
        v(35, 1.8, 7, 0.1, fibres: 2.7)),
    Aliment('Courgette cuite', ['courgette', 'courgettes'],
        v(17, 1.2, 3, 0.3, fibres: 1)),
    Aliment('Aubergine cuite', ['aubergine', 'aubergines'],
        v(35, 1, 9, 0.2, fibres: 2.5)),
    Aliment('Poivron', ['poivron', 'poivrons'], v(27, 1, 6, 0.3, fibres: 2.1)),
    Aliment('Oignon', ['oignon', 'oignons', 'echalote'],
        v(40, 1.1, 9, 0.1, fibres: 1.7)),
    Aliment('Champignons de Paris', ['champignon', 'champignons', 'mushrooms'],
        v(22, 3.1, 1, 0.3, fibres: 0.9)),
    Aliment('Petits pois cuits', ['petits pois', 'pois'],
        v(78, 5.5, 12, 0.4, fibres: 5)),
    Aliment('Avocat', ['avocat', 'avocats', 'guacamole'],
        v(160, 2, 9, 15, fibres: 6.7)),
    Aliment('Maïs en boîte', ['mais', 'corn', 'grains de mais'],
        v(86, 3.2, 19, 1.2, sucres: 6)),
    Aliment(
        'Soupe de légumes',
        ['soupe', 'potage', 'veloute', 'soupe de legumes'],
        v(35, 1.5, 5, 1, fibres: 1)),

    // ---- Fruits ----
    Aliment('Pomme', ['pomme', 'pommes', 'golden'],
        v(52, 0.3, 14, 0.2, fibres: 2.4, sucres: 10)),
    Aliment('Banane', ['banane', 'bananes'],
        v(89, 1.1, 23, 0.3, fibres: 2.6, sucres: 12)),
    Aliment('Orange', ['orange', 'mandarine', 'clementine', 'agrumes'],
        v(47, 0.9, 12, 0.1, fibres: 2.4, sucres: 9)),
    Aliment('Fraises', ['fraise', 'fraises', 'framboises', 'fruits rouges'],
        v(32, 0.7, 7.7, 0.3, fibres: 2, sucres: 4.9)),
    Aliment('Raisin', ['raisin', 'raisins'],
        v(69, 0.7, 18, 0.2, fibres: 0.9, sucres: 16)),
    Aliment(
        'Kiwi', ['kiwi', 'kiwis'], v(61, 1.1, 15, 0.5, fibres: 3, sucres: 9)),
    Aliment('Ananas', ['ananas'], v(50, 0.5, 13, 0.1, fibres: 1.4, sucres: 10)),
    Aliment('Poire', ['poire', 'poires'],
        v(57, 0.4, 15, 0.1, fibres: 3.1, sucres: 9.8)),
    Aliment('Pêche', ['peche', 'nectarine', 'peches'],
        v(39, 0.9, 10, 0.3, fibres: 1.5, sucres: 8)),
    Aliment('Mangue', ['mangue', 'mangues'],
        v(60, 0.8, 15, 0.4, fibres: 1.6, sucres: 14)),
    Aliment('Abricots secs', ['abricots secs', 'fruits secs', 'figues seches'],
        v(240, 3.4, 63, 0.5, fibres: 7.3, sucres: 54)),
    Aliment('Amandes', ['amande', 'amandes', 'amandes grillees'],
        v(579, 21, 22, 50, fibres: 12.5, sucres: 4.4)),
    Aliment('Noix', ['noix', 'noisettes', 'noix de pecan', 'cacahuetes'],
        v(654, 15, 14, 65, fibres: 7)),

    // ---- Produits laitiers ----
    Aliment('Yaourt nature', ['yaourt', 'yogurt', 'yaourt nature'],
        v(62, 4.3, 4.7, 3.2, sucres: 4.7)),
    Aliment(
        'Yaourt aux fruits',
        ['yaourt aux fruits', 'yaourt sucre', 'yaourt a la fraise'],
        v(95, 3.8, 15, 2.5, sucres: 14)),
    Aliment('Fromage blanc', ['fromage blanc', 'faisselle', 'saint moret'],
        v(95, 8, 3.5, 4.3, sucres: 3.5)),
    Aliment('Lait demi-écrémé', ['lait', 'lait demi ecreme', 'verre de lait'],
        v(47, 3.3, 4.7, 1.7, sucres: 4.7)),
    Aliment('Emmental', ['emmental', 'gruyere', 'raclette', 'fromage a fondre'],
        v(380, 27, 0, 29, sel: 1.2)),
    Aliment('Camembert', ['camembert', 'brie'], v(300, 19, 1, 24, sel: 2.5)),
    Aliment('Comté', ['comte', 'comte vieux', 'beaufort'],
        v(400, 29, 0, 31, sel: 1.1)),
    Aliment('Mozzarella', ['mozzarella', 'bocconcini'], v(280, 20, 2, 21)),
    Aliment('Fromage de chèvre', ['chevre', 'fromage de chevre', 'crottin'],
        v(320, 19, 1, 26, sel: 2)),
    Aliment('Beurre', ['beurre', 'beurre doux'], v(745, 0.7, 0.6, 82)),
    Aliment('Crème fraîche', ['creme', 'creme fraiche', 'creme epaisse'],
        v(380, 2.5, 3, 40)),

    // ---- Matières grasses, sucres ----
    Aliment('Huile d\'olive',
        ['huile d olive', 'huile', 'huile d olive vierge'], v(884, 0, 0, 100)),
    Aliment(
        'Huile végétale',
        [
          'huile de tournesol',
          'huile de colza',
          'huile vegetale',
          'huile de pepins'
        ],
        v(884, 0, 0, 100)),
    Aliment('Mayonnaise', ['mayonnaise', 'mayo', 'sauce mayonnaise'],
        v(680, 1, 2, 74)),
    Aliment(
        'Miel', ['miel', 'cuillere de miel'], v(304, 0.3, 82, 0, sucres: 82)),
    Aliment('Sucre', ['sucre', 'sucre blanc', 'sucre roux'],
        v(400, 0, 100, 0, sucres: 100)),
    Aliment('Confiture', ['confiture', 'gele', 'confiture de fraise'],
        v(260, 0.3, 64, 0, sucres: 64)),
    Aliment('Sirop d\'érable', ['sirop d erable', 'maple syrup'],
        v(260, 0, 67, 0, sucres: 67)),

    // ---- Douceurs ----
    Aliment(
        'Chocolat noir',
        ['chocolat noir', 'dark chocolate', 'carre de chocolat'],
        v(550, 7.8, 46, 35, fibres: 11, sucres: 24)),
    Aliment(
        'Chocolat au lait',
        ['chocolat au lait', 'chocolat', 'choco', 'tablette'],
        v(535, 7.6, 59, 30, sucres: 56)),
    Aliment(
        'Pâte à tartiner chocolat-noisette',
        ['pate a tartiner', 'nutella', 'pate a tartiner au chocolat'],
        v(539, 6, 57, 31, sucres: 57)),
    Aliment(
        'Biscuits sablés',
        [
          'biscuit',
          'biscuits',
          'cookie',
          'cookies',
          'gateau sec',
          'petit beurre'
        ],
        v(480, 6, 66, 21, sucres: 30)),
    Aliment('Chips', ['chips', 'crisps', 'tortillas chips'],
        v(536, 7, 53, 34, fibres: 4.8)),
    Aliment(
        'Glace à la vanille',
        ['glace', 'ice cream', 'coupe glacee', 'sundae'],
        v(207, 3.5, 24, 11, sucres: 21)),
    Aliment(
        'Compote de pommes',
        ['compote', 'compote de pommes', 'apple sauce'],
        v(70, 0.2, 16, 0.1, fibres: 1.5, sucres: 14)),
    Aliment(
        'Céréales petit-déjeuner',
        ['cereales', 'corn flakes', 'cornflakes', 'choco pops'],
        v(380, 8, 80, 2, fibres: 5, sucres: 30)),
    Aliment('Muesli', ['muesli', 'granola'],
        v(370, 10, 60, 8, fibres: 8, sucres: 15)),

    // ---- Plats composés ----
    Aliment('Pizza', ['pizza', 'part de pizza', 'margherita', 'pizza reine'],
        v(266, 11, 33, 10, fibres: 2.3, sucres: 3.6, sel: 1.4)),
    Aliment('Lasagne', ['lasagne', 'lasagnes', 'gratin de pates'],
        v(132, 8, 12, 5.5)),
    Aliment(
        'Sandwich jambon-beurre',
        ['sandwich', 'jambon beurre', 'baguette jambon', 'panini'],
        v(300, 12, 30, 14)),
    Aliment(
        'Burger', ['burger', 'hamburger', 'cheeseburger'], v(295, 17, 24, 15)),
    Aliment('Sushi', ['sushi', 'makis', 'california rolls', 'nigiri'],
        v(145, 6, 30, 1.5)),
    Aliment('Tajine', ['tajine', 'tagine'], v(120, 9, 6, 6)),
    Aliment(
        'Couscous complet',
        ['couscous royal', 'couscous legumes', 'couscous complet', 'couscous'],
        v(180, 9, 20, 6)),
    Aliment(
        'Ratatouille',
        ['ratatouille', 'legumes poeles', 'legumes rotis', 'legumes grilles'],
        v(60, 1.5, 8, 3, fibres: 2)),
    Aliment('Salade César', ['salade cesar', 'caesar', 'cesar salad'],
        v(190, 12, 6, 13)),
    Aliment(
        'Salade composée',
        ['salade composee', 'buddha bowl', 'bowl', 'poke bowl'],
        v(150, 8, 10, 8)),
    Aliment(
        'Soupe de nouilles asiatique',
        ['soupe de nouilles', 'ramen', 'pho', 'bouillon de nouilles'],
        v(80, 4, 10, 2)),

    // ---- Végétal / substituts ----
    Aliment('Falafel', ['falafels', 'falafel', 'crepes de pois chiches'],
        v(333, 13, 32, 18, fibres: 5)),
    Aliment('Houmous', ['houmous', 'hummus'], v(240, 8, 14, 16, fibres: 6)),
    Aliment('Tofu', ['tofu', 'tofu nature', 'tofu ferme'], v(76, 8, 1.9, 4.8)),
    Aliment('Seitan', ['seitan', 'proteines vegetales', 'proteine de ble'],
        v(141, 25, 14, 2)),
    Aliment(
        'Lait d\'amande',
        ['lait d amande', 'lait vegetal', 'boisson d amande'],
        v(24, 0.5, 2.4, 1.4)),
    Aliment(
        'Lait d\'avoine', ['lait d avoine', 'oat drink'], v(45, 1, 6.7, 1.5)),

    // ---- Boissons ----
    Aliment(
        'Eau',
        ['eau', 'eau plate', 'eau minerale', 'verre d eau', 'eau gazeuse'],
        v(0, 0, 0, 0)),
    Aliment('Café noir', ['cafe', 'cafe noir', 'espresso', 'cafe serre'],
        v(2, 0.1, 0, 0)),
    Aliment(
        'Café au lait',
        ['cafe au lait', 'cafe creme', 'latte', 'cappuccino'],
        v(40, 2.4, 4, 1.6)),
    Aliment(
        'Jus d\'orange',
        ['jus d orange', 'jus de fruits', 'orange juice', 'jus'],
        v(45, 0.7, 10, 0.2, sucres: 9)),
    Aliment('Soda', ['coca', 'cola', 'soda', 'boisson gazeuse', 'limonade'],
        v(42, 0, 10.6, 0, sucres: 10.6)),
    Aliment('Bière', ['biere', 'blonde', 'pinte de biere'], v(43, 0.5, 3.6, 0)),
    Aliment(
        'Vin rouge', ['vin', 'vin rouge', 'verre de vin'], v(85, 0.1, 2.6, 0)),
  ];
}
