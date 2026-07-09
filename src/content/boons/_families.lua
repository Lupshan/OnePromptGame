-- The six Remnants: dead powers of the burned world, each with a clear
-- mechanical identity. Duo boons cross two of them.
local boons = require("src.game.boons")

boons.defineFamily({ id = "ember", name = "Ember", motto = "What burned once burns again.",
  color = { 1.0, 0.5, 0.2 } })
boons.defineFamily({ id = "tempest", name = "Tempest", motto = "The sky kept its anger.",
  color = { 1.0, 0.95, 0.45 } })
boons.defineFamily({ id = "gloom", name = "Gloom", motto = "Everything ends. Help it.",
  color = { 0.7, 0.45, 1.0 } })
boons.defineFamily({ id = "verdance", name = "Verdance", motto = "Life is stubborn.",
  color = { 0.45, 1.0, 0.55 } })
boons.defineFamily({ id = "aegis", name = "Aegis", motto = "Stand. Hold. Answer.",
  color = { 0.4, 0.75, 1.0 } })
boons.defineFamily({ id = "zephyr", name = "Zephyr", motto = "Never be where the blow lands.",
  color = { 0.55, 0.95, 0.9 } })
boons.defineFamily({ id = "ash", name = "Ash", motto = "What remains, remains yours.",
  color = { 0.8, 0.78, 0.75 } })

return {}
