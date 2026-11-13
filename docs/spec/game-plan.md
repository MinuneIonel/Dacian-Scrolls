<!-- Text export of https://claude.ai/artifact/KSp3BF4KU1JPb3CQB6xNxk (2026-11-12). The live doc is the source of truth. -->

# Dacian Scrolls: Game Plan
 · 

## Pitch and pillars
The recommendation: build Dacian Scrolls as a 2D isometric, turn-based party RPG in Godot 4, and prove it with a one-region vertical slice before building anything else.
Pitch. Dacia, anul 101. Trajan's legions are at the border, but the real threat is in the sky: the Lobizi, 15-metre giants of a lost Pacific civilization returning from the astral plane, are abducting villagers, seeding strange tech and rewriting history. You lead a band of Dacian heroes across a Fallout-style world map, mixing the magic of Zalmoxis with salvaged alien technology, until the Lobizi play their last card: a politician pulled from the future.
Design pillars (every feature should serve at least one):

- Dacia, but weird. Real history and Romanian folklore (the Draco wolf banner, Sarmizegetusa, strigoi, pricolici) collide with flying saucers and ray guns. Played straight enough to feel grounded, absurd enough to be funny.

- The journey is the game. Travel across a world map is risky and full of surprises: random encounters, UFOs hunting your party, places you stumble on.

- Your party, your story. Companions with their own personalities, opinions and quests; class and ability choices that change how fights play.

- Magic meets tech. Every class has a folk-magic side and a Lobizi-tech side, and the fun is in combining them.

## Engine and tech stack
Use Godot 4 with GDScript, and make the game 2D isometric. It is free with no royalties, has the best 2D tooling of the main engines, is quick for a small team to learn, and exports to Windows, Mac, Linux, web and Steam Deck from one project. If someone on the team already knows Unity well, that is the one good reason to pick Unity instead.
Option
 | Good for
 | Downsides for this game
 | Verdict
 | 
Godot 4 (GDScript or C#)
 | 2D and isometric tilemaps, small teams, fast iteration, free and open source
 | Smaller asset store; console ports need a third-party porting studio
 | Recommended
 | 
Unity 6 (C#)
 | Huge asset store and tutorials, proven for isometric RPGs, easier console ports
 | Heavier editor; licence and pricing history makes some teams wary
 | Pick only if the team already knows it
 | 
Unreal 5
 | High-end 3D visuals
 | Overkill and slow to iterate for a 2D RPG; C++ or Blueprints learning curve
 | No
 | 
Web (Phaser or PixiJS + TypeScript)
 | Instant browser demos, easy sharing
 | You end up building your own editor, save system and tools; a long RPG outgrows it
 | Fine for a throwaway prototype only
 | 
RPG Maker
 | Very fast for classic JRPGs
 | Fights its own design: hard to do Fallout-style world travel and tactical combat
 | No
 | 
Why 2D isometric, not 3D. The Fallout 1 and 2 look you are referencing is isometric 2D. It is also far cheaper to produce: one artist can draw tiles, sprites and portraits, while 3D needs modelling, rigging, animation and lighting for every character and building. A 2.5D look (3D-rendered sprites, like the original Fallouts) is possible later without changing engines.
Supporting tools

- Art: Aseprite for pixel art, or Krita / Photoshop for hand-painted sprites; Tiled or Godot's built-in TileMap for maps.

- Dialogue: a Godot dialogue plugin such as Dialogic or Dialogue Manager, so writers can work without touching code.

- Music and sound: a DAW of the composer's choice (Reaper is cheap and popular); Godot's audio buses handle layered, adaptive music. FMOD is an option if the music becomes very dynamic.

- Code and assets: Git with Git LFS on GitHub for versioning; a simple task board (GitHub Projects, Trello or similar).

- Distribution: Steam (Steamworks) as the main target, itch.io for early public demos.

## Game design
The core loop: travel the world map, get pulled into encounters or abductions, explore cities for quests, gear and companions, fight in turn-based tactical combat, and grow the party toward the final confrontation.

### Setting and the Lobizi
The Lobizi come from a real (and gloriously unhinged) source: a single Romanian book of spiritist séance "communications", dated to 1953, in which their dead leader Fanfi dictates their history from beyond. We play that source completely straight-faced, which is where the comedy comes from.

### The Lobizi: canon from the book

- Deep time. Earth is 33 întregi old (a billion years each: 500 million of evolution, 500 million of involution). The Lobizi lived in the 15th.

- Giants. Men 15 m tall, women 12 m, lifespans over 10,000 years.

- Origin. Reincarnated sinners dropped from the astral plane in bancuri of 33,000, all aged 33. They started as hairy, speechless, raw-meat-eating blood drinkers.

- Empire. 216 million of them, leading an alliance with the ianzi, angani and farizi: almost a billion people. Probably Atlantis; now under the Pacific.

- Rulers. Bertimeg the conqueror (died "fighting the fish", body never found), Filo the reformer (abolished slavery, invented four castes by height and age), Hali (Sun worship, human sacrifice, warm blood at festivals), and Fanfi, who ruled 8,723 years until the cataclysm.

- Peak civilization. Glass houses run "on buttons", solar power, flying spintecătoare, moving sidewalks, a centrală vibratorie phone in every home, typewriters doing 100,000 words a minute, atomic medicine, deliveries every 188 hours, no markets, lots of cofetării. Ruled by a council of 70 sages, none younger than 9,000.

- Spirituality. The philosopher Fehet taught one god, Aul, who revealed their doom 1,500 years ahead. The scholar Mirg wrote down every person's whole life at birth. They reached the state of puri and owned the oglinda, a mirror linking them to the spirits above.

### How the game uses it
The premise. The cataclysm didn't finish the Lobizi; it sent them back up to the astral plane. Through the oglinda they have watched the world for ages, and in anul 101 they come back down: the UFOs are their spintecătoare, 15-metre giants step out of the forests, and they want Dacia as their new homeland. To everyone in 101 they look exactly like aliens.
The Scrolls versus Mirg's book. Mirg wrote everyone's fate in advance, and the Lobizi have a copy with Dacia's ending in it: conquest, Lobidization, cofetării on every corner. The Dacian Scrolls are the hero rewriting that fate page by page. Free will versus a 15-metre bureaucracy.
Fanfi as narrator. The game is framed as a séance. Fanfi, smug and long-winded, narrates and argues with the player ("communication of 25 April 1953: I would like to state that we did nothing wrong"). A perfect vehicle for self-aware jokes, unreliable history and fourth-wall breaks.
Comedy hooks straight from canon

- Their tech parodies ours: the 100,000-words-a-minute typewriter is basically AI slop, the 188-hour deliveries are Prime, the centrală vibratorie is a phone they never put down.

- A caste system based on how tall you are, so the Dacians are all legally "snacks".

- Saler's 100 identical talking icons of Aul, all talking at once, as a cursed side quest.

- Bertimeg's lost body and the fish war, as a running joke that pays off in a secret boss: the Fish.

- Hard-coded base-12 everything, because a woman's height was the unit of measure.
Enemy roster
Enemy
 | From the canon
 | How it fights
 | 
Bancul recruit
 | Fresh reincarnated savage, 33,000 at a time
 | Hairy, feral swarms; bite and drink blood to heal
 | 
Lobid citizen
 | 12 m civilian in cis robes, deeply confused to be fighting
 | Weak but huge; drops tech loot
 | 
Grazi thrall
 | Conquered tribe, "Lobidized"
 | Human-sized soldiers serving the giants
 | 
Spintecătoare
 | Their flying craft
 | The UFOs on the world map; abducts the party
 | 
Sun priest of Hali
 | Sacrifice cult
 | Buffs allies by sacrificing them; blood festival arenas
 | 
Mirg's scribe
 | Fate writers
 | Writes your character's death in advance; you must act before the line finishes
 | 
The council of 70 sages
 | 9,000-year-old bureaucrats
 | Mini-boss that passes laws mid-fight changing the rules
 | 
Bertimeg, Risen
 | The lost conqueror, returned
 | Late-game boss, half-eaten by fish
 | 
Fanfi
 | The narrator himself
 | Turns out to be the second-to-last boss, still talking
 | 
Twist. Losing, Fanfi uses the oglinda to look into the future for the one person whose speeches can rewrite Dacian history better than Mirg's book: enter the final boss, imported from the 2020s.

### World map and travel
Travel works like Fallout 1 and 2: the party is a marker on a large map, you click a destination, and time passes as you move.

- Fog of war: the map reveals as you explore; locations appear when you pass near them or hear about them.

- Random encounters: each travel tick rolls against the terrain's danger level. Results range from fights (Lobizi scouts, bandits, Roman patrols, strigoi) to traders, wanderers, and rare special encounters (an easter egg or a crashed saucer).

- Encounter maps: a fight or event drops the party onto a small local map matching the terrain (forest, mountain pass, Danube bank).

- Survival-lite: food and days passing matter a little (to make travel decisions interesting), but not enough to be a chore.

### Cities and outskirts
Each major location is a hand-made isometric map with a town (or fortress) and an outskirts area. Towns hold quest givers, traders, recruitable companions, a temple or healer, and a tavern for rumours that reveal new map locations. Outskirts hold the dungeons, caves, Roman camps and crash sites. Candidate locations: Sarmizegetusa (capital and hub), Apulon, Porolissum, a Danube crossing near Drobeta, a Roman legionary camp, and a hidden Lobizi base in the Carpathians.

### Classes
Each class has two ability trees: a folk-magic tree and a Lobizi-tech tree unlocked by salvaging alien devices. Names are working titles.
Class
 | Theme
 | Role
 | Magic tree example
 | Tech tree example
 | 
Knight (Tarabostes)
 | Armoured Dacian noble with shield and falx
 | Tank, protects the party
 | Draco's Ward: taunt and damage shield
 | Plasma-edged falx
 | 
Barbarian (Comat)
 | Wild mountain warrior
 | Melee damage, rage
 | Wolf Fury: berserk bonus at low health
 | Alien stim injector
 | 
Necromancer (Strigoi-caller)
 | Calls the restless dead of folklore
 | Summoner, debuffs
 | Raise strigoi from fallen enemies
 | Reanimate dead Lobizi drones
 | 
Healer (Priest of Zalmoxis)
 | Servant of the Dacian god of the afterlife
 | Healing and buffs
 | Blessing of Zalmoxis: heal and cleanse
 | Alien med-gel field
 | 
Archer (Horse Archer)
 | Scout and marksman
 | Ranged damage, traps
 | Wind-guided arrows
 | Laser-scoped bow
 | 
Seer (optional)
 | Oracle reading stars and saucers
 | Crowd control
 | Prophecy: see enemy turns ahead
 | Mind-scrambler
 | 
Players pick one class for their hero; companions cover the others.

### Party and companions

- Party of up to 4 (the hero plus 3 companions), recruited in towns or through quests.

- Each companion has a fixed class, a personal quest, opinions about your choices (approval that can make them leave or unlock bonuses), and banter while travelling.

- Aim for about 6 to 8 companions in the full game, for example a disgraced Roman deserter, a wise-cracking village witch, a Lobizi defector.

### Combat and abilities

- Turn-based on a grid with action points, like Fallout and modern tactical RPGs: moving, attacking and using abilities all spend AP.

- Cover, height and flanking matter; the environment can be used (oil jars, Roman siege gear, alien power cells).

- Abilities cost either Mana (magic) or Charge (tech, recharged with alien power cells), which keeps the two sides of each class feeling different.

- Combos between party members are the fun part: for example the Seer stuns, the Necromancer raises the stunned enemy as a minion.

### UFO abductions
UFOs are visible on the world map as moving shadows. If one catches the party marker, a beam cutscene plays and the party wakes up inside the saucer for a mini-boss fight in a special arena with alien hazards (gravity zones, specimen tanks, a self-destruct timer). Winning gives rare Lobizi tech for the tech trees; losing drops you somewhere strange on the map rather than ending the game. Players can also learn to avoid UFOs (travel at night, hide in forests, decoy charms), so it is a risk they can choose to take for loot.
Each region's UFO has its own mini-boss, such as a Lobizi surgeon, a cattle-obsessed probe drone, or a captured Roman centurion turned cyborg.

### Final boss: the parody
The Lobizi, losing the war, reach into the future and import their ultimate weapon: a satirical parody of Călin Georgescu. The fight should be clearly comedic and over the top, for example phases that mock his speeches and talking points, attacks themed on his well-known claims, and a finale that ties back to Dacian history he likes to invoke. Keep it as obvious satire of public statements and persona rather than invented factual claims. Before launch it is worth deciding whether to use his real name and likeness or a thinly veiled parody name (for example "Călin din Viitor"), since some storefronts and jurisdictions are stricter about real people.

### Soundtrack

- Direction: Dacian and Romanian folk instruments (nai pan flute, caval, cobză, tulnic alphorn, drums, throat-style chanting) blended with analogue synths when the aliens show up. Folk for the land, synth for the Lobizi, both mixed in the boss fights.

- Adaptive music: each region has an exploration track with a combat layer that fades in, plus stingers for abductions and level-ups.

- Budget: roughly 15 to 25 tracks for the full game. Options are a composer on the team, a commissioned indie composer (typically a few hundred euros per finished minute, varies a lot), or licensed stock music for prototypes only. Recording real folk musicians for a few key themes would make the game stand out.

## Design lens: what the player gets to be
Games are an art of agency: we don't design the experience directly, we design who the player gets to be (goals, abilities, the world pushing back) and the experience follows. Looked at that way, Dacian Scrolls already has a strong fantasy in your notes: a Dacian hero who survives by turning the invaders' own tools against them. Every system below should feed that feeling.

### 1. Change the goal before adding mechanics
The goal is the cheapest and strongest lever on how people play. If XP comes from kills, players will fight everything. So:

- The goal is to write the Dacian Scrolls. The Lobizi are erasing Dacia's history. The player collects lost pages (from quests, ruins, crash sites, companions' stories) and the scroll is the progress bar and the save screen. It turns exploration and talking into progress, and it explains the title.

- XP comes from salvage and discovery, not kills. Sneaking past, talking someone down or scaring an enemy off counts as much as winning a fight, like the original Fallouts. This gives every encounter real choices.

### 2. Each class is a different way of thinking
A class shouldn't just be different numbers; it should be a different mode of attention. Then combos between them feel like teamwork rather than math.
Class
 | The way you think when playing it
 | What it needs from the others
 | 
Knight
 | Where to stand: you protect, body-block and control space
 | Someone to deal the damage behind you
 | 
Barbarian
 | Risk: you get stronger the closer you are to falling
 | A healer who heals you late, not early
 | 
Necromancer
 | Economy: every enemy that falls is a resource to raise
 | Enemies falling in the right places
 | 
Healer
 | Triage: who to save this turn, and who can wait
 | Time, bought by the Knight
 | 
Archer
 | Looking ahead: traps and shots set up turns in advance
 | Enemies pushed into the kill zone
 | 
Seer
 | Information: sees what enemies will do next turn
 | Teammates who act on what the Seer reveals
 | 

### 3. UFO abductions: forbid the default
An abduction must be fun to receive, otherwise it is just a punishment. The trick is to forbid what the player normally relies on, so they discover a new way to play:

- Magic doesn't work inside the saucer (Zalmoxis can't hear you up there). Only Lobizi tech and plain steel work, so the tech half of every class suddenly matters.

- Gravity is broken. Wobbly floaty movement for a few turns is funny on purpose, a chance for slapstick in the middle of a boss fight.

- Players choose the risk. UFO shadows are visible on the map, and the best tech only drops in abductions, so getting abducted becomes a gamble they take for loot, not bad luck.

### 4. Abilities: just barely enough
The best moments come when the party's abilities, used at full stretch, just barely beat the problem. So we hand out fewer, sharper abilities (around 4 per character active at once) instead of a big menu, and tune fights so a good combo wins and button-mashing doesn't. Difficulty settings let each player find their own edge.

### 5. Travel: every stop is a decision
Random encounters with no choices turn into a grind. Each encounter should offer at least two ways out (fight, talk, sneak, bribe, run), and travel itself should involve trade-offs: the fast road with UFO patrols, or the forest path that is safe but costs food and days.

### 6. The final boss: satire you play, not just watch
The parody lands best if it is a mechanic, not only a costume. The boss doesn't just hit hard; he gives speeches that win over the crowd (enemies, ghosts of Dacian kings, even your own companions) and every convinced listener makes him stronger. To win, the party has to expose the nonsense: the Seer reveals what's really behind each claim, the Healer snaps confused allies out of it, the Knight holds the line, and only once the spell breaks can he be beaten. It is a joke about persuasion and a real test of everything the player learned, kept silly and kid-friendly.

### 7. A good ending isn't a score
No endless loot treadmill or daily-reward loops. The ending is the finished scroll: a recap of your journey, the companions you kept and the choices you made. The question we want players asking at the end is "was that a great adventure?", not "what was my number?"

### Who we are making it for
Tone: Gen Z edgy self-satire. The game knows exactly how absurd it is (a 1953 séance about 15-metre Atlanteans invading Dacia) and leans in with deadpan narration, meme-aware jokes and fourth-wall breaks, without turning every line into a meme. The rule of thumb: the world takes itself seriously, the narrator doesn't.
Gore: yes, over the top. Think splatter comedy rather than grim realism: giants popping like water balloons, critical hits with absurd death animations, a blood-drinking enemy faction straight from the canon. Like Fallout's "Bloody Mess" perk, it's part of the joke. We add a gore setting (Off / Normal / Bloody Mess): it costs little to build, helps with age ratings and store pages, and means younger playtesters can still join in.
Players come for different things: some for the spectacle (UFOs, giants, big bosses), some to build clever combos, some to beat it on hard. The game should offer all three.

## Technical architecture
The game splits into three main modes that hand the same party data back and forth, with all game content stored as data files so designers can add classes, abilities and enemies without new code.

- Global game state (autoload): party members, inventory, quest flags, world time, companion approval. Every mode reads and writes this one place.

- World map scene: the travel marker, fog of war, encounter rolls, UFO movement. Triggers a switch to a location or encounter.

- Location scene: an isometric tilemap for a town, outskirts or encounter area, with NPCs, dialogue triggers, containers and exits back to the world map.

- Combat scene (or combat mode inside a location): grid, turn order, action points, abilities, enemy AI. Returns results (loot, XP, deaths) to the game state.

- Data as Godot Resources: one file per class, ability, item, enemy and encounter table. Balancing becomes editing numbers, not code.

- Dialogue and quests: dialogue in the plugin's script format with conditions on quest flags and companion approval.

- Saving: serialise the game state plus the current scene to JSON; autosave on every map transition.
Build the combat system and the save system early: they touch everything else, and retrofitting them is the most common way indie RPGs stall.

## First milestone: the vertical slice
The first milestone is a 20 to 30 minute playable slice of one region that proves every core system works together, at near-final quality for that small area. It answers the only question that matters early: is this fun?
In scope

- One region of the world map (around Sarmizegetusa) with travel, fog of war and 3 discoverable locations

- One town with 5 to 8 NPCs, a trader, a healer and 2 short quests

- One outskirts area or cave with a small dungeon

- 2 playable classes (Knight and Necromancer) plus 1 recruitable companion (Healer)

- Turn-based combat with action points, 6 to 8 abilities total, 4 to 5 enemy types

- Random encounter table for the region (3 to 4 encounter types)

- One UFO abduction with its mini-boss arena

- One music track with an exploration and combat layer, plus ambience and core sound effects

- Save and load, a main menu, basic settings
Out of scope for now: the final boss, the full class roster, companion approval systems, crafting, other regions, voice acting.
Rough effort: about 3 to 5 months for 2 people working part-time (one mostly code, one mostly art and design), with music commissioned or made in parallel. This depends heavily on your answers to the questions at the end.

## Roadmap
The full game is roughly 16 to 25 months away for a small part-time team, and the vertical slice is the go/no-go point before committing to full production.
Each gate is a moment to stop and decide: continue, cut scope, or change direction. Durations are rough guesses for 2 to 3 part-time people and will be redone once we know the team.

## Risks and open questions
Biggest risks

- Scope. A Fallout-style RPG with cities, companions and multiple classes is a lot for a small team. The slice and the region-by-region plan are there to keep it shippable; cut regions before cutting quality.

- Combat feel. Turn-based combat that is slow or samey sinks the whole game. Prototype it first and playtest often.

- Art volume. Every class, enemy and companion needs sprites in several directions and animations. Lock a style that one artist can sustain.

- The parody boss. Using a real, living politician can draw attention (good and bad) and some legal or platform scrutiny. Keep it clearly satirical and decide on the name question before marketing.
Questions for you and your associate (your answers will reshape the timeline and some recommendations):

- Team: answered. Claude builds it; you and your associate are the designers and playtesters.

- Skills: for the designers: what does a Lobiz look like, and what's the coolest ability you can imagine?

- Platform: PC on Steam first, or do you also want browser, mobile or consoles?

- 2D or 3D: are you happy with 2D isometric, or is 3D important to you?

- Art style: pixel art, hand-painted, or pre-rendered 3D sprites like the original Fallouts? Any reference games you love the look of?

- Tone: how much is it a comedy versus a serious RPG with jokes?

- Language: Romanian, English, or both from day one?

- Budget and goal: is this a passion project, or are you aiming to sell it? Is there money for a composer or artist?
