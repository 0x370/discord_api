package dungeon

import "core:fmt"
import "core:strings"

import discord "../../discord"

@(private)
handle_rates :: proc(ctx: ^discord.Command_Context) {
	total_weight := 0
	for w in TIER_WEIGHTS do total_weight += w

	lines := make([dynamic]string, context.temp_allocator)
	append(&lines, "**Tier Drop Rates** (per roll, 5 rolls per lootbox)")
	append(&lines, "```")
	for t in TIER_COLLECTION_ORDER {
		w := TIER_WEIGHTS[t]
		pct := f64(w) * 100.0 / f64(total_weight)
		append(&lines, fmt.tprintf("%-12s %2d/%d = %5.1f%%", TIER_LABELS[t], w, total_weight, pct))
	}
	append(&lines, "```")
	append(&lines, fmt.tprintf("Expected per 5-pull: ~%.1f Mythical, ~%.1f Legendary, ~%.1f Rare, ~%.1f Uncommon, ~%.1f Common",
		f64(TIER_WEIGHTS[.MYTHICAL])*5.0/f64(total_weight),
		f64(TIER_WEIGHTS[.LEGENDARY])*5.0/f64(total_weight),
		f64(TIER_WEIGHTS[.RARE])*5.0/f64(total_weight),
		f64(TIER_WEIGHTS[.UNCOMMON])*5.0/f64(total_weight),
		f64(TIER_WEIGHTS[.COMMON])*5.0/f64(total_weight),
	))

	append(&lines, "")
	append(&lines, "**Combat Lootbox Drops**")
	append(&lines, "```")
	append(&lines, "Normal victory: 8% chance for 1 item lootbox")
	append(&lines, "Boss victory:    2 guaranteed item lootboxes")
	append(&lines, "Daily:           +2 character lootboxes")
	append(&lines, "```")

	append(&lines, "")
	append(&lines, "**Tier Item Stats**")
	append(&lines, "```")
	append(&lines, "            Mult  Affixes  Affix Range  Specials")
	for t in TIER_COLLECTION_ORDER {
		cfg := TIER_CONFIGS[t]
		affix_str := cfg.max_affixes == 0 ? "0" : fmt.tprintf("%d-%d", cfg.min_affixes, cfg.max_affixes)
		spec_str  := cfg.max_specials == 0 ? "0" : fmt.tprintf("%d-%d", cfg.min_specials, cfg.max_specials)
		append(&lines, fmt.tprintf("%-12s x%-4.2f %-7s %d-%-10d %s",
			TIER_LABELS[t], cfg.mult, affix_str, cfg.affix_min, cfg.affix_max, spec_str))
	}
	append(&lines, "```")

	append(&lines, fmt.tprintf("💰 Sell prices: Common=%d  Uncommon=%d  Rare=%d  Legendary=%d  Mythical=%d + affix bonus",
		_sell_price(ItemInstance{tier=.COMMON}),
		_sell_price(ItemInstance{tier=.UNCOMMON}),
		_sell_price(ItemInstance{tier=.RARE}),
		_sell_price(ItemInstance{tier=.LEGENDARY}),
		_sell_price(ItemInstance{tier=.MYTHICAL}),
	))
	append(&lines, fmt.tprintf("🎭 Mythical chars get an S-ability | Weapon: 50%% Sword / 50%% Staff"))
	append(&lines, fmt.tprintf("🗡️ Item type: equal 1/6 chance each | Specials: no duplicates per item"))

	discord.respond(ctx, strings.join(lines[:], "\n", context.temp_allocator))
}

@(private)
register_rates_handlers :: proc(client: ^discord.Client) {
	discord.on_command(client, "rates", "Show dungeon drop rates and tier info", handle_rates)
}
