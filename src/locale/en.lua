-- English strings (reference language). Keys missing from other locales
-- fall back to these. UI first; `content` holds translations of content
-- defs keyed by id (en usually empty: defs are authored in English).
return {
  ui = {
    common = {
      back = "back",
      confirmKey = "SPACE",
      cancelKey = "ESC",
    },

    title = {
      tagline = "the world burned. keep moving.",
      menu_begin = "Begin",
      menu_kiln = "The Kiln",
      menu_codex = "Codex",
      menu_options = "Options",
      menu_help = "How to Play",
      menu_quit = "Quit",
      stats = "cinders %d   ·   runs %d   ·   victories %d",
    },

    charselect = {
      header = "CHOOSE YOUR REMNANT",
      sealedName = "???",
      sealedHint = "Sealed.\n\nLight this wraith at the Kiln.",
      footer = "<- -> choose · SPACE begin · ESC back",
    },

    kiln = {
      header = "THE KILN",
      sub = "cinders buy new possibilities — never raw power",
      lit = "lit",
      already = "Already burning.",
      kindled = "%s kindled.",
      notEnough = "Not enough cinders.",
      footer = "up/down browse · SPACE kindle · ESC back",
    },

    codex = {
      header = "CODEX",
      tab_enemies = "Enemies",
      tab_boons = "Boons",
      tab_wardens = "Wardens",
      witnessed = "%d / %d witnessed",
      unwitnessed = "— unwitnessed —",
      footer = "<- -> tabs · up/down scroll · ESC back",
    },

    gameover = {
      header = "THE ASH TAKES YOU BACK",
      fellIn = "fell in %s  ·  depth %d",
      killsTime = "%d kills  ·  %s survived",
      cinders = "%d cinders carried home",
      seed = "seed %d",
      carried = "carried: %s",
      kilnHolds = "the Kiln holds %d cinders",
      footer = "[SPACE] rise again      [TAB] the Kiln      [ESC] title",
    },

    victory = {
      header = "THE SPIRE FALLS QUIET",
      sub = "what burned is finally allowed to rest",
      clearedIn = "cleared in %s",
      killsRooms = "%d kills  ·  %d rooms",
      cinders = "%d cinders earned (+%d victory tribute)",
      asChar = "as %s  ·  seed %d",
      footer = "[SPACE] return to the ash",
    },

    pause = {
      header = "PAUSED",
      resume = "Resume",
      music = "Music volume",
      sfx = "Sound volume",
      shake = "Screen shake",
      language = "Language",
      remap = "Controls",
      abandon = "Abandon run",
    },

    options = {
      header = "OPTIONS",
      language = "Language",
      music = "Music volume",
      sfx = "Sound volume",
      shake = "Screen shake",
      remap = "Remap controls",
      reset = "Reset controls to defaults",
      footer = "up/down select · <- -> adjust · SPACE enter · ESC back",
      remapHeader = "CONTROLS",
      remapHint = "SPACE on an action, then press the new key",
      pressKey = "press a key...",
      remapFooter = "up/down select · SPACE rebind · ESC back",
      resetDone = "Controls reset.",
    },

    help = {
      header = "HOW TO PLAY",
      lines = {
        "CENDRE is a platformer first: every room is a traversal challenge.",
        "Reach the exit door. Enemies are obstacles on the way — fighting is optional",
        "in most rooms. Sealed arenas and Wardens must be fought.",
        "",
        "Chain your movement: jumps buffer just before landing, and the ledge",
        "forgives you for a few frames after you step off (jump anyway!).",
        "Dashing makes you briefly untouchable. Striking downward in the air",
        "bounces you off enemies — it refreshes your dash and jumps.",
        "",
        "Each run: pick boons to build power, cross four regions, kill the Warden.",
        "Death keeps only cinders — spend them at the Kiln to widen what can appear.",
      },
      controlsHeader = "DEFAULT CONTROLS",
    },

    actions = {
      left = "Move left",
      right = "Move right",
      up = "Aim up / enter",
      down = "Aim down / drop",
      jump = "Jump",
      attack = "Attack",
      dash = "Dash",
      interact = "Interact",
      map = "Map / skip",
      pause = "Pause",
    },

    hud = {
      dash = "dash",
      enemies = "enemies: %d",
      wave = "wave %d/%d",
      biomeDepth = "%s  ·  depth %d",
      seed = "seed %s",
      sealed = "the exit is sealed — clear the arena",
    },

    boonpick = {
      header = "THE ASH OFFERS",
      instructions = "choose with <- -> · take with SPACE · [TAB] refuse (+15 embers)",
      levelUp = "Lv %d→%d",
    },

    map = {
      header_hint = "choose your path  ·  <- -> + SPACE",
      current = "you are here",
      label_start = "Entrance",
      label_traversal = "Traversal",
      label_combat = "Contested path",
      label_arena = "Sealed arena",
      label_treasure = "Treasure",
      label_shop = "Shop",
      label_rest = "Rest spring",
      label_event = "Shrine",
      label_boss = "Warden",
    },

    room = {
      open = "open",
      commune = "commune",
      drink = "drink",
      offer = "offer",
      buy = "%s  [%d]",
      mend = "Mend 40 HP",
      shrine_blood = "The shrine takes %d blood. It gives back power.",
      shrine_embers = "The shrine hums. Embers spill out.",
      shrine_cinders = "Something old approves. Cinders remain.",
      shrine_deepen = "The stones listen. %s deepens.",
      shrine_deepen_none = "The stones find nothing to deepen. Embers, then.",
      shrine_greed_win = "The shrine matches your purse. +%d embers.",
      shrine_greed_lose = "The shrine laughs. %d embers gone.",
      shrine_mend = "It mends you, and borrows your strength a while.",
      hint_move = "move",
      hint_jump = "jump  (hold = higher)",
      hint_dash = "dash",
      hint_attack = "attack",
    },

    rarity = {
      common = "Common",
      rare = "Rare",
      epic = "Epic",
      heroic = "Heroic",
    },
  },

  content = {
    -- English content text lives on the defs themselves.
    boons = {},
    enemies = {},
    biomes = {},
    characters = {},
    unlocks = {},
    families = {},
    bosses = {},
  },
}
