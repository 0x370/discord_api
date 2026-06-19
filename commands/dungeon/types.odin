package dungeon

Tier :: enum {
	MYTHICAL,
	LEGENDARY,
	RARE,
	UNCOMMON,
	COMMON,
}

Weapon_Compat :: enum {
	SWORD,
	STAFF,
}

Class_Type :: enum {
	ATTACKER,
	HEALER,
}

Class_Base :: struct {
	hp:                int,
	atk:               int,
	def:               int,
	mana:              int,
	mana_regen:        int,
	ability_mana_cost: int,
}

Item_Type :: enum {
	SWORD,
	STAFF,
	HELM,
	CHEST,
	LEGS,
	BOOTS,
}

Item_Slot :: enum {
	WEAPON,
	HEAD,
	CHEST,
	LEGS,
	BOOTS,
}

CollectedCharacter :: struct {
	id:           i64,
	user_id:      string,
	name:         string,
	tier:         Tier,
	weapon_compat: Weapon_Compat,
	ability_name: string,
	ability_desc: string,
}

ItemInstance :: struct {
	id:           i64,
	user_id:      string,
	item_type:    Item_Type,
	tier:         Tier,
	base_atk:     int,
	base_def:     int,
	bonus_hp:     int,
	bonus_atk:    int,
	bonus_def:    int,
	bonus_spd:    int,
	bonus_crit:   int,
	special:      string,
	floor:        int,
}

Player :: struct {
	user_id:           string,
	equipped_char_id:  i64,
	gold:              int,
	item_lootboxes:    int,
	char_lootboxes:    int,
	daily_streak:      int,
	last_daily_claim:  i64,
	current_floor:     int,
	class:             Class_Type,
	weapon_id:         i64,
	head_id:           i64,
	chest_id:          i64,
	legs_id:           i64,
	boots_id:          i64,
}

Monster_Kind :: enum {
	Normal,
	Rare,
	Boss,
}

MonsterTemplate :: struct {
	name:          string,
	kind:          Monster_Kind,
	emoji:         string,
	base_hp:       int,
	base_atk:      int,
	base_def:      int,
	scale_hp:      int,
	scale_atk:     int,
	scale_def:     int,
	base_mana:     int,
	mana_regen:    int,
	gold_min:      int,
	gold_max:      int,
	lootbox_chance: f64,
	boss_ability:   string,
}

CombatEvent :: enum {
	START,
	TURN_START,
	ON_ATTACK,
	ON_ABILITY,
	ON_DAMAGE_DEALT,
	ON_DAMAGE_TAKEN,
	ON_HEAL,
	ON_KILL,
	ON_DEATH,
	ON_REVIVE,
	VICTORY,
	DEFEAT,
}

CombatHook :: #type proc(state: ^CombatState)
CombatPlayer :: struct {
	name:      string,
	class:     Class_Type,
	max_hp:    int,
	hp:        int,
	atk:       int,
	def:       int,
	max_mana:  int,
	mana:      int,
	mana_regen: int,
}

CombatMonster :: struct {
	name:      string,
	kind:      Monster_Kind,
	emoji:     string,
	hp:        int,
	max_hp:    int,
	atk:       int,
	def:       int,
	max_mana:  int,
	mana:      int,
	mana_regen: int,
	ability_name: string,
}

EncounterState :: enum {
	PLAYER_TURN,
	MONSTER_TURN,
	PLAYER_WON,
	PLAYER_LOST,
}

CombatBuffs :: struct {
	shield:                int,
	monster_bleed:         int,
	player_atk_ramp:       int,
	block_charges:         int,
	monster_atk_debuff:    bool,
	monster_frozen:        int,
	stun_freeze_cooldown:  int,
	block_cooldown:        int,
	crit_chance:            int,
	total_bonus_spd:       int,
}

CombatCaps :: struct {
	bonus_attack_procs:    int,
	life_steal_total:      int,
	shield_this_turn:      bool,
	heal_this_turn:        bool,
	regen_this_turn:       bool,
	boss_resist_used:      bool,
	thorns_used:           bool,
	def_reduce_done:       bool,
	lightning_this_turn:   bool,
	char_revive_used:      bool,
}

CombatTracking :: struct {
	first_attack:          bool,
	last_damage_dealt:     int,
	last_damage_taken:     int,
	monster_stunned:       bool,
	pending_heal:          int,
	monster_original_atk:  int,
	player_base_atk:       int,
}

CombatState :: struct {
	player:                 CombatPlayer,
	monster:                CombatMonster,
	floor:                  int,
	boss_floor:             bool,
	state:                  EncounterState,
	turn:                   int,
	ability_cooldown:       int,
	char_ability_cooldown:  int,
	char_ability_name:      string,
	class_ability_name:     string,
	ability_mana_cost:      int,
	char_ability_mana_cost: int,
	buffs:                  CombatBuffs,
	caps:                   CombatCaps,
	track:                  CombatTracking,
	hooks:                  map[CombatEvent][dynamic]CombatHook,
	reward_mult:            f64,
	rare_mult:              f64,
	log:                    [dynamic]string,
	reward_gold:            int,
	reward_lootboxes:       int,
	active:                 bool,
	interaction_token:      string,
	message_id:             string,
	channel_id:             string,
}

CharacterGachaResult :: struct {
	name:         string,
	tier:         Tier,
	weapon_compat: Weapon_Compat,
	ability_name: string,
	ability_desc: string,
}

ItemGachaResult :: struct {
	item_type:    Item_Type,
	tier:         Tier,
	base_atk:     int,
	base_def:     int,
	bonus_hp:     int,
	bonus_atk:    int,
	bonus_def:    int,
	bonus_spd:    int,
	bonus_crit:   int,
	special:      string,
	floor:        int,
}

Affix :: enum {
	HP,
	ATK,
	DEF,
	SPD,
	CRIT,
}

Tier_Config :: struct {
	name:      string,
	label:     string,
	mult:      f64,
	min_affixes: int,
	max_affixes: int,
	affix_min: int,
	affix_max: int,
	min_specials: int,
	max_specials: int,
}

Sell_Session :: struct {
	user_id:    string,
	item_ids:   []i64,
	item_count: int,
	total_gold: int,
	message_id: string,
	step:       int,
	is_char:    bool,
}
