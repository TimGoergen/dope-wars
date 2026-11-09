class_name TuningConfig
extends Resource

# Canonical tuning configuration for Dope Wars: Omaha Metro Edition (GDD v1.1).
# No tuning numbers are hardcoded in game logic; everything is read from res://config/tuning.tres
# and overridden via user://tuning_overrides.json when edited in the on-device Dev Tuning panel.

# --- 1. Starting State & Run Lengths ------------------------------------------------------------
@export var starting_cash: int = 2000
@export var starting_debt: int = 5500
@export var starting_bank: int = 0
@export var starting_health: int = 100
@export var starting_capacity: int = 100
@export var default_run_days: int = 31

# --- 2. Banking, Street ATM & Big Sal Loan Shark ------------------------------------------------
@export var loan_interest_rate: float = 0.10
@export var loan_interest_perk_rate: float = 0.08
@export var bank_interest_rate: float = 0.05
@export var bank_interest_perk_rate: float = 0.07
@export var street_atm_fee_rate: float = 0.05
@export var final_day_debt_penalty_mult: float = 1.5
@export var credit_line_min: int = 25000
@export var credit_line_net_worth_pct: float = 0.50
@export var credit_line_cap: int = 250000
@export var enforcer_unpaid_days: int = 7
@export var enforcer_min_payment_pct: float = 0.10
@export var enforcer_damage: int = 20
@export var enforcer_cash_seize_pct: float = 0.25

# --- 3. Market Engine, Affinities & 4x/1/4 Events -----------------------------------------------
@export var market_availability_chance: float = 0.60
@export var spike_multiplier: float = 4.0
@export var flood_divisor: float = 4.0
@export var max_events_per_day: int = 2
@export var event_slot_chance: float = 0.35
@export var primary_event_weight: float = 0.70
@export var affinity_cheap_mult: float = 0.85
@export var affinity_mild_cheap_mult: float = 0.90
@export var affinity_very_cheap_mult: float = 0.80
@export var affinity_pricy_mult: float = 1.15
@export var affinity_west_o_mult: float = 1.20

# --- 4. The 12 Products (Min / Max Normal Prices) -----------------------------------------------
@export var price_min_adderall: int = 11
@export var price_max_adderall: int = 60
@export var price_min_meth: int = 90
@export var price_max_meth: int = 250
@export var price_min_vape_carts: int = 220
@export var price_max_vape_carts: int = 700
@export var price_min_weed: int = 315
@export var price_max_weed: int = 890
@export var price_min_hashish: int = 480
@export var price_max_hashish: int = 1280
@export var price_min_oxy: int = 540
@export var price_max_oxy: int = 1250
@export var price_min_shrooms: int = 630
@export var price_max_shrooms: int = 1300
@export var price_min_acid: int = 1000
@export var price_max_acid: int = 4400
@export var price_min_pcp: int = 1000
@export var price_max_pcp: int = 2500
@export var price_min_molly: int = 1500
@export var price_max_molly: int = 4400
@export var price_min_heroin: int = 5500
@export var price_max_heroin: int = 13000
@export var price_min_cocaine: int = 15000
@export var price_max_cocaine: int = 29000

# --- 5. Weapons, Armor, Crew & Capacity ---------------------------------------------------------
@export var weapon_trade_in_pct: float = 0.50
@export var armor_vest_price: int = 8500
@export var armor_vest_amount: int = 50
@export var armor_plate_price: int = 35000
@export var armor_plate_amount: int = 100
@export var crew_base_cost: int = 20000
@export var crew_step_cost: int = 10000
@export var crew_max_count: int = 10
@export var crew_capacity_bonus: int = 10
@export var crew_encounter_hp: int = 30
@export var carhartt_pocket_bonus: int = 40
@export var carhartt_base_cost: int = 200

# --- 6. Police Heat & Combat --------------------------------------------------------------------
@export var heat_per_cop_kill: float = 12.0
@export var heat_per_run_attempt: float = 5.0
@export var heat_big_trade_threshold: int = 100000
@export var heat_big_trade_gain: float = 5.0
@export var heat_passive_decay: float = 3.0
@export var heat_bellevue_decay: float = 18.0
@export var heat_ambush_scale: float = 0.35
@export var scanner_perk_ambush_reduction: float = 5.0
@export var crew_target_chance: float = 0.50
@export var base_escape_chance: float = 0.55
@export var escape_penalty_per_backup: float = 0.06
@export var surrender_cash_loss_pct: float = 0.25
@export var surrender_heat_reset: float = 10.0

# --- 7. District Facilities & Street Encounters -------------------------------------------------
@export var clinic_min_cost_per_hp: int = 100
@export var clinic_max_cost_per_hp: int = 1000
@export var clinic_net_worth_scale: float = 0.002
@export var kidney_sale_payout: int = 2500
@export var kidney_max_hp_cap: int = 80
@export var casino_min_bet: int = 1000
@export var casino_max_bet: int = 100000
@export var casino_launder_cut_pct: float = 0.10
@export var casino_launder_heat_drop: float = 15.0
@export var lawyer_base_cost: int = 1500
@export var lawyer_partial_heat_drop: float = 35.0
@export var lawyer_cost_per_heat: float = 120.0
@export var lawyer_relative_suppress_pct: float = 0.10
@export var vip_intel_base_cost: int = 1000
@export var vip_intel_day_step_cost: int = 250
@export var street_event_chance: float = 0.28
