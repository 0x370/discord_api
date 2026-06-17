package dungeon

Tier :: enum {
	S,
	A,
	B,
	C,
	D,
	F,
}

Class_Type :: enum {
	ATTACKER,
	HEALER,
}

Class_Base :: struct {
	hp:  int,
	atk: int,
	def: int,
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
	class:        Class_Type,
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
	special:      string,
}

Player :: struct {
	user_id:           string,
	equipped_char_id:  i64,
	gold:              int,
	item_lootboxes:    int,
	current_floor:     int,
	class:             Class_Type,
	weapon_id:         i64,
	head_id:           i64,
	chest_id:          i64,
	legs_id:           i64,
	boots_id:          i64,
}

MonsterTemplate :: struct {
	name:          string,
	emoji:         string,
	boss:          bool,
	rare:          bool,
	base_hp:       int,
	base_atk:      int,
	base_def:      int,
	scale_hp:      int,
	scale_atk:     int,
	scale_def:     int,
	gold_min:      int,
	gold_max:      int,
	lootbox_chance: f64,
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
	name:    string,
	class:   Class_Type,
	max_hp:  int,
	hp:      int,
	atk:     int,
	def:     int,
}

CombatMonster :: struct {
	name:   string,
	emoji:  string,
	boss:   bool,
	rare:   bool,
	hp:     int,
	max_hp: int,
	atk:    int,
	def:    int,
}

EncounterState :: enum {
	PLAYER_TURN,
	MONSTER_TURN,
	PLAYER_WON,
	PLAYER_LOST,
}

CombatState :: struct {
	player:           CombatPlayer,
	monster:          CombatMonster,
	floor:            int,
	boss_floor:       bool,
	state:            EncounterState,
	turn:             int,
	ability_cooldown: int,
	char_ability_cooldown: int,
	char_ability_name: string,
	class_ability_name: string,
	hooks:            map[CombatEvent][dynamic]CombatHook,
	reward_mult:      f64,
	rare_mult:        f64,
	log:              [dynamic]string,
	reward_gold:      int,
	reward_lootboxes: int,
	active:           bool,
	interaction_token: string,
	message_id:       string,
	channel_id:       string,
}

CharacterGachaResult :: struct {
	name:         string,
	tier:         Tier,
	class:        Class_Type,
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
	special:      string,
}

Affix :: enum {
	HP,
	ATK,
	DEF,
	SPD,
}

Tier_Config :: struct {
	name:      string,
	label:     string,
	mult:      f64,
	min_affixes: int,
	max_affixes: int,
	affix_min: int,
	affix_max: int,
}
