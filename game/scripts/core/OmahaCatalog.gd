class_name OmahaCatalog

# Canonical catalog of the 8 Omaha Metro neighborhoods, 12 products, 5 weapons,
# 2 armors, 5 vehicle tiers, and 6 Legacy Perks (GDD v1.1).

const DISTRICTS := [
	{
		"id": "north_omaha",
		"index": 0,
		"name": "Florence",
		"short_name": "1. Florence",
		"icon": "🏦🦈",
		"facility_id": "bank_and_loans",
		"facility_name": "First National Bank & Big Sal's Loans",
		"facility_btn": "🏦 Bank & Big Sal's Loans",
		"base_cop_pct": 6.0,
		"cheap_products": ["weed", "adderall"],
		"very_cheap_products": [],
		"mild_cheap_products": ["weed", "adderall"],
		"pricy_products": [],
		"west_o_pricy": false,
		"bellevue_chill": false,
		"flavor": "Historic Florence strip — home to First National and Big Sal."
	},
	{
		"id": "south_omaha",
		"index": 1,
		"name": "South Omaha",
		"short_name": "2. South O",
		"icon": "🔫",
		"facility_id": "pawn_gun",
		"facility_name": "24th St. Pawn & Gun",
		"facility_btn": "🔫 24th St. Pawn & Gun",
		"base_cop_pct": 10.0,
		"cheap_products": ["meth", "weed", "pcp"],
		"very_cheap_products": [],
		"mild_cheap_products": [],
		"pricy_products": [],
		"west_o_pricy": false,
		"bellevue_chill": false,
		"flavor": "Industrial working-class strip — best spot to buy heat and Kevlar."
	},
	{
		"id": "benson",
		"index": 2,
		"name": "Benson",
		"short_name": "3. Benson",
		"icon": "🏥",
		"facility_id": "clinic",
		"facility_name": "Benson Back-Alley Clinic",
		"facility_btn": "🏥 Benson Back-Alley Clinic",
		"base_cop_pct": 10.0,
		"cheap_products": ["acid", "shrooms", "vape_carts"],
		"very_cheap_products": [],
		"mild_cheap_products": [],
		"pricy_products": ["molly"],
		"west_o_pricy": false,
		"bellevue_chill": false,
		"flavor": "Maple Street dive bars, indie venues, and a back-alley doc."
	},
	{
		"id": "west_omaha",
		"index": 3,
		"name": "West Omaha",
		"short_name": "4. West O",
		"icon": "🍸",
		"facility_id": "lounge",
		"facility_name": "The Regency Lounge",
		"facility_btn": "🍸 The Regency Lounge (Hire Crew)",
		"base_cop_pct": 22.0,
		"cheap_products": [],
		"very_cheap_products": [],
		"mild_cheap_products": [],
		"pricy_products": ["cocaine", "molly", "oxy", "adderall", "meth", "vape_carts", "heroin"],
		"west_o_pricy": true,
		"bellevue_chill": false,
		"flavor": "Regency & Village Pointe money — top-dollar buyers, heavy OPD."
	},
	{
		"id": "council_bluffs",
		"index": 4,
		"name": "Council Bluffs",
		"short_name": "5. C.Bluffs",
		"icon": "🎰",
		"facility_id": "casino",
		"facility_name": "Riverboat High-Limit Room",
		"facility_btn": "🎰 Riverboat Casino (Bet & Launder)",
		"base_cop_pct": 10.0,
		"cheap_products": ["hashish"],
		"very_cheap_products": ["meth"],
		"mild_cheap_products": ["hashish"],
		"pricy_products": ["pcp"],
		"west_o_pricy": false,
		"bellevue_chill": false,
		"flavor": "Across the Missouri River — riverboat high-limit tables & truck stops."
	},
	{
		"id": "old_market",
		"index": 5,
		"name": "Old Market",
		"short_name": "6. Old Mkt",
		"icon": "⚖️",
		"facility_id": "lawyer",
		"facility_name": "Farnam St. Defense Attorney",
		"facility_btn": "⚖️ Farnam St. Lawyer (Drop Heat)",
		"base_cop_pct": 18.0,
		"cheap_products": [],
		"very_cheap_products": [],
		"mild_cheap_products": [],
		"pricy_products": ["cocaine", "molly", "shrooms", "weed", "hashish", "acid"],
		"west_o_pricy": false,
		"bellevue_chill": false,
		"flavor": "Brick streets, CWS crowds, downtown foot patrols, and a connected lawyer."
	},
	{
		"id": "blackstone",
		"index": 6,
		"name": "Blackstone",
		"short_name": "7. Blackst",
		"icon": "🥂",
		"facility_id": "vip_booth",
		"facility_name": "Farnam VIP Booth",
		"facility_btn": "🥂 Farnam VIP Booth (Market Intel)",
		"base_cop_pct": 14.0,
		"cheap_products": ["adderall", "oxy"],
		"very_cheap_products": [],
		"mild_cheap_products": [],
		"pricy_products": ["molly", "vape_carts"],
		"west_o_pricy": false,
		"bellevue_chill": false,
		"flavor": "UNMC med-center & Farnam nightlife strip — insider market tips."
	},
	{
		"id": "bellevue",
		"index": 7,
		"name": "Bellevue",
		"short_name": "8. Bellev",
		"icon": "🚗",
		"facility_id": "chop_shop",
		"facility_name": "Hwy 75 Auto & Chop Shop",
		"facility_btn": "🚗 Hwy 75 Chop Shop (Vehicles)",
		"base_cop_pct": 6.0,
		"cheap_products": [],
		"very_cheap_products": [],
		"mild_cheap_products": [],
		"pricy_products": [],
		"west_o_pricy": false,
		"bellevue_chill": true,
		"flavor": "Quiet Hwy 75 suburb near Offutt — upgrade vehicles and shed -18% Heat."
	}
]

const PRODUCTS := [
	{
		"id": "adderall",
		"row": 1,
		"name": "Adderall",
		"min_prop": "price_min_adderall",
		"max_prop": "price_max_adderall",
		"primary_event": "flood",
		"flood_msg": "UNMC finals week wrapped up and frat houses on Farnam are dumping cheap Adderall!",
		"spike_msg": "Exam week hit Creighton & UNO! Students are paying outrageous prices for Adderall!"
	},
	{
		"id": "meth",
		"row": 2,
		"name": "Meth",
		"min_prop": "price_min_meth",
		"max_prop": "price_max_meth",
		"primary_event": "spike",
		"spike_msg": "Late-shift truckers along I-80 and Council Bluffs are buying Meth at outrageous prices!",
		"flood_msg": "An Iowa super-lab just dumped a massive batch of cheap Meth across the river!"
	},
	{
		"id": "vape_carts",
		"row": 3,
		"name": "Vape Carts",
		"min_prop": "price_min_vape_carts",
		"max_prop": "price_max_vape_carts",
		"primary_event": "flood",
		"flood_msg": "A van full of dispensary Vape Carts from Missouri just flooded the metro!",
		"spike_msg": "Suburban crackdowns dried up supply! Buyers are paying outrageous prices for Vape Carts!"
	},
	{
		"id": "weed",
		"row": 4,
		"name": "Weed",
		"min_prop": "price_min_weed",
		"max_prop": "price_max_weed",
		"primary_event": "flood",
		"flood_msg": "A convoy from Colorado slipped past the I-80 state troopers! Weed prices have bottomed out!",
		"spike_msg": "State Patrol locked down I-80 at the border! Weed prices are outrageous!"
	},
	{
		"id": "hashish",
		"row": 5,
		"name": "Hashish",
		"min_prop": "price_min_hashish",
		"max_prop": "price_max_hashish",
		"primary_event": "flood",
		"flood_msg": "A fresh shipment of Hashish just rolled off a freight car at the Union Pacific yard!",
		"spike_msg": "Connoisseurs in the Old Market are buying Hashish at outrageous prices!"
	},
	{
		"id": "oxy",
		"row": 6,
		"name": "Oxy",
		"min_prop": "price_min_oxy",
		"max_prop": "price_max_oxy",
		"primary_event": "spike",
		"spike_msg": "DEA shut down a suburban pill mill! Desperate buyers are paying outrageous prices for Oxy!",
		"flood_msg": "A rival crew knocked over a pharmacy on Saddle Creek and is dumping cheap Oxy!"
	},
	{
		"id": "shrooms",
		"row": 7,
		"name": "Shrooms",
		"min_prop": "price_min_shrooms",
		"max_prop": "price_max_shrooms",
		"primary_event": "flood",
		"flood_msg": "An underground grower in Council Bluffs harvested a massive flush of cheap Shrooms!",
		"spike_msg": "A jam-band tour stopped at the CHI Center! Fans are buying Shrooms at outrageous prices!"
	},
	{
		"id": "acid",
		"row": 8,
		"name": "Acid",
		"min_prop": "price_min_acid",
		"max_prop": "price_max_acid",
		"primary_event": "flood",
		"flood_msg": "A basement chemist in Benson just flooded the market with cheap home-made Acid!",
		"spike_msg": "Benson art-walk weekend has buyers paying outrageous prices for Acid!"
	},
	{
		"id": "pcp",
		"row": 9,
		"name": "PCP",
		"min_prop": "price_min_pcp",
		"max_prop": "price_max_pcp",
		"primary_event": "spike",
		"spike_msg": "Biker gangs passing through I-29 are buying PCP at outrageous prices!",
		"flood_msg": "South Omaha street chemists overproduced PCP—prices have crashed!"
	},
	{
		"id": "molly",
		"row": 10,
		"name": "Molly",
		"min_prop": "price_min_molly",
		"max_prop": "price_max_molly",
		"primary_event": "spike",
		"spike_msg": "A weekend EDM festival at the riverfront has ravers buying Molly at outrageous prices!",
		"flood_msg": "A Chicago courier just unloaded a trunk full of cheap Molly in Blackstone!"
	},
	{
		"id": "heroin",
		"row": 11,
		"name": "Heroin",
		"min_prop": "price_min_heroin",
		"max_prop": "price_max_heroin",
		"primary_event": "spike",
		"spike_msg": "OPD raided a major stash house! Heroin prices are outrageous!",
		"flood_msg": "Cartel wholesalers flooded I-80 with uncut Heroin—prices have plummeted!"
	},
	{
		"id": "cocaine",
		"row": 12,
		"name": "Cocaine",
		"min_prop": "price_min_cocaine",
		"max_prop": "price_max_cocaine",
		"primary_event": "spike",
		"spike_msg": "College World Series fans packed downtown! Buyers are paying outrageous prices for Cocaine!",
		"flood_msg": "A diplomatic courier plane landed at Eppley Airfield and flooded Omaha with cheap Cocaine!"
	}
]

const WEAPONS := [
	{
		"id": "ruger_22",
		"tier": 1,
		"name": "Ruger .22 Pistol",
		"short_name": ".22 Pistol",
		"price": 1500,
		"damage": 5,
		"hit_chance": 0.65
	},
	{
		"id": "beretta_9mm",
		"tier": 2,
		"name": "Beretta 9mm",
		"short_name": "Beretta 9mm",
		"price": 5000,
		"damage": 10,
		"hit_chance": 0.70
	},
	{
		"id": "mossberg_12g",
		"tier": 3,
		"name": "Mossberg 12-Gauge",
		"short_name": "12g Shotgun",
		"price": 15000,
		"damage": 22,
		"hit_chance": 0.75
	},
	{
		"id": "ar15_pistol",
		"tier": 4,
		"name": "Sawed-Off AR-15",
		"short_name": "AR-15 Pistol",
		"price": 40000,
		"damage": 40,
		"hit_chance": 0.80
	},
	{
		"id": "micro_draco",
		"tier": 5,
		"name": "Full-Auto Micro Draco",
		"short_name": "Micro Draco",
		"price": 95000,
		"damage": 75,
		"hit_chance": 0.85
	}
]

const VEHICLES := [
	{
		"tier": 0,
		"id": "on_foot",
		"name": "On Foot / ORBT Bus",
		"short_name": "ORBT Bus",
		"price": 0,
		"bonus_capacity": 0,
		"escape_bonus": 0.0,
		"cop_dmg_reduction": 0.0
	},
	{
		"tier": 1,
		"id": "civic_98",
		"name": "'98 Honda Civic",
		"short_name": "'98 Civic",
		"price": 12000,
		"bonus_capacity": 60,
		"escape_bonus": 0.05,
		"cop_dmg_reduction": 0.0
	},
	{
		"tier": 2,
		"id": "chevy_tahoe",
		"name": "Chevy Tahoe (Tinted)",
		"short_name": "Tinted Tahoe",
		"price": 55000,
		"bonus_capacity": 150,
		"escape_bonus": 0.10,
		"cop_dmg_reduction": 0.0
	},
	{
		"tier": 3,
		"id": "cargo_van",
		"name": "Ford E-350 Cargo Van",
		"short_name": "Cargo Van",
		"price": 200000,
		"bonus_capacity": 320,
		"escape_bonus": 0.15,
		"cop_dmg_reduction": 0.0
	},
	{
		"tier": 4,
		"id": "armored_escalade",
		"name": "Armored Escalade ESV",
		"short_name": "Escalade ESV",
		"price": 750000,
		"bonus_capacity": 600,
		"escape_bonus": 0.25,
		"cop_dmg_reduction": 0.20
	}
]

const LEGACY_PERKS := [
	{
		"id": "connected_cousin",
		"name": "Connected Cousin",
		"cost": 1,
		"desc": "Big Sal's daily loan interest drops from 10% to 8%."
	},
	{
		"id": "glovebox_22",
		"name": "Glovebox .22",
		"cost": 1,
		"desc": "Start Day 1 with a Ruger .22 Pistol already equipped."
	},
	{
		"id": "carhartt_xl",
		"name": "Carhartt XL",
		"cost": 2,
		"desc": "Start Day 1 with 140 Carry Capacity instead of 100."
	},
	{
		"id": "first_national_vip",
		"name": "First National VIP",
		"cost": 2,
		"desc": "Bank interest rises to 7%/day, 0% Street ATM fee, and remote withdrawals anywhere."
	},
	{
		"id": "police_scanner",
		"name": "Police Scanner",
		"cost": 3,
		"desc": "Shows a 24h market event forecast and reduces Police Ambush chance by -5%."
	},
	{
		"id": "civic_keys",
		"name": "'98 Civic Keys",
		"cost": 4,
		"desc": "Start Day 1 driving the '98 Honda Civic (+60 Trunk Space, +5% Run Chance)."
	}
]


static func get_district(district_id: String) -> Dictionary:
	for d in DISTRICTS:
		if d["id"] == district_id:
			return d
	return DISTRICTS[0]


static func get_product(product_id: String) -> Dictionary:
	for p in PRODUCTS:
		if p["id"] == product_id:
			return p
	return PRODUCTS[0]


static func get_weapon(weapon_id: String) -> Dictionary:
	for w in WEAPONS:
		if w["id"] == weapon_id:
			return w
	return WEAPONS[0]


static func get_vehicle(tier: int) -> Dictionary:
	var idx := clampi(tier, 0, VEHICLES.size() - 1)
	return VEHICLES[idx]


static func get_perk(perk_id: String) -> Dictionary:
	for p in LEGACY_PERKS:
		if p["id"] == perk_id:
			return p
	return LEGACY_PERKS[0]
