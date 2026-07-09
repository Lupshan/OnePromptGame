-- Chaînes françaises. Les clés absentes retombent sur l'anglais (en.lua).
-- La section `content` sera remplie au fil des passes de traduction.
return {
  ui = {
    common = {
      back = "retour",
      confirmKey = "ESPACE",
      cancelKey = "ÉCHAP",
    },

    title = {
      tagline = "le monde a brûlé. continue d'avancer.",
      menu_begin = "Commencer",
      menu_kiln = "Le Four",
      menu_codex = "Codex",
      menu_options = "Options",
      menu_help = "Comment jouer",
      menu_quit = "Quitter",
      stats = "cendres %d   ·   tentatives %d   ·   victoires %d",
    },

    charselect = {
      header = "CHOISIS TON VESTIGE",
      sealedName = "???",
      sealedHint = "Scellé.\n\nRallume ce spectre au Four.",
      footer = "<- -> choisir · ESPACE commencer · ÉCHAP retour",
    },

    kiln = {
      header = "LE FOUR",
      sub = "les cendres achètent des possibles — jamais de la puissance brute",
      lit = "allumé",
      already = "Brûle déjà.",
      kindled = "%s embrasé.",
      notEnough = "Pas assez de cendres.",
      footer = "haut/bas parcourir · ESPACE embraser · ÉCHAP retour",
    },

    codex = {
      header = "CODEX",
      tab_enemies = "Ennemis",
      tab_boons = "Faveurs",
      tab_wardens = "Gardiens",
      witnessed = "%d / %d rencontrés",
      unwitnessed = "— jamais vu —",
      footer = "<- -> onglets · haut/bas défiler · ÉCHAP retour",
    },

    gameover = {
      header = "LA CENDRE TE REPREND",
      fellIn = "tombé dans %s  ·  profondeur %d",
      killsTime = "%d victimes  ·  %s survécu",
      cinders = "%d cendres rapportées",
      seed = "graine %d",
      carried = "portait : %s",
      kilnHolds = "le Four garde %d cendres",
      footer = "[ESPACE] se relever      [TAB] le Four      [ÉCHAP] titre",
    },

    victory = {
      header = "LA FLÈCHE SE TAIT",
      sub = "ce qui a brûlé peut enfin se reposer",
      clearedIn = "terminé en %s",
      killsRooms = "%d victimes  ·  %d salles",
      cinders = "%d cendres gagnées (+%d tribut de victoire)",
      asChar = "avec %s  ·  graine %d",
      footer = "[ESPACE] retourner à la cendre",
    },

    pause = {
      header = "PAUSE",
      resume = "Reprendre",
      music = "Volume musique",
      sfx = "Volume effets",
      shake = "Secousse d'écran",
      language = "Langue",
      remap = "Contrôles",
      abandon = "Abandonner la tentative",
    },

    options = {
      header = "OPTIONS",
      language = "Langue",
      music = "Volume musique",
      sfx = "Volume effets",
      shake = "Secousse d'écran",
      remap = "Redéfinir les touches",
      reset = "Réinitialiser les touches",
      footer = "haut/bas choisir · <- -> ajuster · ESPACE entrer · ÉCHAP retour",
      remapHeader = "CONTRÔLES",
      remapHint = "ESPACE sur une action, puis presse la nouvelle touche",
      pressKey = "appuie sur une touche...",
      remapFooter = "haut/bas choisir · ESPACE réassigner · ÉCHAP retour",
      resetDone = "Touches réinitialisées.",
    },

    help = {
      header = "COMMENT JOUER",
      lines = {
        "CENDRE est d'abord un platformer : chaque salle est un défi de traversée.",
        "Atteins la porte de sortie. Les ennemis sont des obstacles en chemin — le",
        "combat est optionnel dans la plupart des salles. Arènes scellées et",
        "Gardiens, eux, doivent être affrontés.",
        "",
        "Enchaîne tes mouvements : le saut se mémorise juste avant l'atterrissage,",
        "et le rebord te pardonne quelques instants après l'avoir quitté (saute !).",
        "Le dash te rend brièvement intouchable. Frapper vers le bas en l'air te",
        "fait rebondir sur les ennemis — et recharge dash et sauts.",
        "",
        "Chaque tentative : choisis des faveurs, traverse quatre régions, tue le",
        "Gardien. La mort ne garde que les cendres — dépense-les au Four pour",
        "élargir ce qui peut apparaître.",
      },
      controlsHeader = "TOUCHES PAR DÉFAUT",
    },

    actions = {
      left = "Aller à gauche",
      right = "Aller à droite",
      up = "Viser haut / entrer",
      down = "Viser bas / descendre",
      jump = "Sauter",
      attack = "Attaquer",
      dash = "Dash",
      interact = "Interagir",
      map = "Carte / passer",
      pause = "Pause",
    },

    hud = {
      dash = "dash",
      enemies = "ennemis : %d",
      wave = "vague %d/%d",
      biomeDepth = "%s  ·  profondeur %d",
      seed = "graine %s",
      sealed = "la sortie est scellée — vide l'arène",
    },

    boonpick = {
      header = "LA CENDRE PROPOSE",
      instructions = "choisis avec <- -> · prends avec ESPACE · [TAB] refuser (+15 braises)",
      levelUp = "Niv %d→%d",
    },

    map = {
      header_hint = "choisis ta route  ·  <- -> + ESPACE",
      current = "tu es ici",
      label_start = "Entrée",
      label_traversal = "Traversée",
      label_combat = "Passage disputé",
      label_arena = "Arène scellée",
      label_treasure = "Trésor",
      label_shop = "Boutique",
      label_rest = "Source",
      label_event = "Sanctuaire",
      label_boss = "Gardien",
    },

    room = {
      open = "ouvrir",
      commune = "communier",
      drink = "boire",
      offer = "offrir",
      buy = "%s  [%d]",
      mend = "Soigner 40 PV",
      shrine_blood = "Le sanctuaire prend %d de sang. Il rend du pouvoir.",
      shrine_embers = "Le sanctuaire fredonne. Des braises s'échappent.",
      shrine_cinders = "Quelque chose d'ancien approuve. Des cendres restent.",
      shrine_deepen = "Les pierres écoutent. %s s'approfondit.",
      shrine_deepen_none = "Rien à approfondir. Des braises, alors.",
      shrine_greed_win = "Le sanctuaire double ta bourse. +%d braises.",
      shrine_greed_lose = "Le sanctuaire rit. %d braises envolées.",
      shrine_mend = "Il te répare, et t'emprunte tes forces un moment.",
      hint_move = "bouger",
      hint_jump = "sauter  (maintenir = plus haut)",
      hint_dash = "dash",
      hint_attack = "attaquer",
    },

    rarity = {
      common = "Commune",
      rare = "Rare",
      epic = "Épique",
      heroic = "Héroïque",
    },
  },

  content = {
    boons = {},
    enemies = {},
    biomes = {},
    characters = {},
    unlocks = {},
    families = {},
    bosses = {},
  },
}
