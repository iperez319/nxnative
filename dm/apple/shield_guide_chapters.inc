// Original directions and activity cards based on the Shield route and the
// official strategy guide's walkthrough, subevent index and Champion's Guide.
static NSString *laterDirections(DMGuideArea area) {
    switch (area) {
        case DMGuideAreaMine2:
            return @"Enter from Hulbury’s harbor after the Water Badge. Bede waits near the entrance with Solosis Lv. 21, Gothita and Galarian Ponyta Lv. 22, and Hatenna Lv. 23. Ghost or Bug moves help against his Psychic team.\n\n"
                @"Past the pool, join Hop against two Grunts. They use Galarian Linoone Lv. 22 and Pancham Lv. 21, plus Thievul Lv. 21 and Liepard Lv. 22. Fairy moves help against all four. Follow the tracks to meet Kabu, then leave toward Motostoke Outskirts. Return with Water Mode for TM53 past the fishing pool.";
        case DMGuideAreaOutskirts:
            return @"From the mine exit, take the grass path south for pickups, then follow the bridge west into Motostoke. Check the bridge railings for recurring feathers. You can also take a Flying Taxi into town. Heal before visiting Marnie at the Budew Drop Inn, then return to the stadium in the morning.";
        case DMGuideAreaNorthWild:
            return @"Cross the bridge east of Motostoke into Motostoke Riverbank. Follow the eastern route past the Bridge Field Nursery and the Route 5 bridge, then turn north toward Hammerlocke. The city gate checks for the Fire Badge. Return with Water Mode to reach the Lake of Outrage bluff.";
        case DMGuideAreaHammerlocke:
            return @"Meet Chairman Rose and Bede outside the stadium, then follow Rose into the lobby. From the stadium, head west past the Centers to meet Raihan at the vault. Take the stairs for Sonia’s tapestry scene and two Revives. Leave west for Route 6.\n\n"
                @"After the Fairy Badge, you can travel here with Opal. Meet Bede near the stadium, then Sonia and Leon on the way east. Speak to Hop near the station before heading to Route 7. The eastern Pokémon Center and its TM shop open by this visit.\n\n"
                @"After Spikemuth, return for the Dragon Gym. Begin the mission at the vault and face Raihan in doubles. After the eighth badge, take the train to Route 10.";
        case DMGuideAreaRoute6:
            return @"Cross the bridge west of Hammerlocke. Team Yell uses Stunky Lv. 29 and Galarian Linoone Lv. 30, then Liepard Lv. 30. Try Ground against Stunky and Fighting against the other two. Opal gives you her League Card afterward.\n\n"
                @"Past the bridge, use the ladders to explore the upper ledges. Watch for Cara Liss and the campsite before taking the route under the stone arch to Stow-on-Side. Check the far-right ladder by the arch before dropping back down toward the ponds.";
        case DMGuideAreaStow:
            return @"Heal at the Center before approaching Hop at the stadium stairs. Hop brings Cramorant Lv. 28 or 29, Toxel Lv. 29, Silicobra Lv. 30 and the Lv. 33 evolved starter weak to yours. After the match, Opal gives you Allister’s League Card.\n\n"
                @"After earning the Ghost Badge, take the west stairs to the mural. Bede uses Duosion and Gothorita Lv. 32, Galarian Ponyta Lv. 33 and Hattrem Lv. 35. Bug or Ghost attacks are useful. Talk to Sonia at the newly exposed statues before leaving for Glimwood Tangle.";
        case DMGuideAreaGlimwood:
            return @"Enter after the mural scene and Bede’s battle in Stow-on-Side. Touch glowing mushrooms for light. At the first fork, the west branch passes Cook Derek and the east branch passes the Full Heals and Big Root. Head north toward Ballonlea. The ledges along Madame Judy’s path drop back to the main trail.";
        case DMGuideAreaBallonlea:
            return @"Follow the path toward the stadium and speak to Marnie on your first visit. Frank is in the southern house, and the older woman and Elena are in the northern house. Check in under the arch for Opal’s Fairy Gym. After the badge, meet Opal outside and accept her offer to travel to Hammerlocke or head there yourself.";
        case DMGuideAreaRoute7:
            return @"Cross the bridge east of Hammerlocke and meet Hop. His team has Trevenant and Heatmor Lv. 34, Snorlax and Boltund Lv. 35, and the Lv. 37 starter weak to yours. Go north through the arch into Route 8.\n\n"
                @"When you reach Outer Spikemuth from Circhester Bay, take the Route 9 Tunnel west to reach the other half of Route 7. Visit Renee’s camp, then take the side path below the east bridge.";
        case DMGuideAreaRoute8:
            return @"Follow the ladders through the ruins and watch the Falinks crossing between wall tunnels. Detour east at the far arch for Lisa’s camp. Go north through the arch and follow Steamdrift Way past Bobby to Circhester.";
        case DMGuideAreaCirchester:
            return @"Explore the two Hotel Ionia buildings on either side of the plaza. Use the east elevator for the detective and TM gifts, and the west elevator for the game director. The Hero’s Bath is below the stadium.\n\n"
                @"After the Ice Badge, meet Sonia at Bob’s Your Uncle, then follow her and Hop to the Hero’s Bath. Heal before battling Hop. He uses Dubwool and Corviknight Lv. 40, Pincurchin and Snorlax Lv. 39, and the Lv. 41 starter weak to yours. Afterward take the southeast exit to Route 9.";
        case DMGuideAreaRoute9:
            return @"Fish from the bridge south of Circhester or continue down the coast to the doctor in Circhester Bay. The Grunt uses Galarian Linoone Lv. 39 and Pangoro Lv. 40. Fighting works well against Linoone and Fairy against Pangoro. The doctor upgrades the bike afterward.\n\n"
                @"Ride across the bay toward the slope into Outer Spikemuth. Explore the islands and coves before leaving. At the closed front gate, look for Marnie by the lower path. She uses Liepard Lv. 42, Toxicroak and Scrafty Lv. 43, and Morpeko Lv. 44. Look for the Route 9 Tunnel west of the grass for a shortcut to Route 7.";
        case DMGuideAreaSpikemuth:
            return @"Follow Marnie through the side entrance after your Route 9 battle. Heal at the Pokémon Center before following the main street to the stage. After the Dark Badge and the scene outside, take the Route 9 Tunnel back toward Hammerlocke.";
        case DMGuideAreaRoute10:
            return @"From the station, follow the snowy climb north to Wyndon. Heal before the climb and plan for several Trainer battles. At the end, follow the road to Wyndon Stadium.";
        case DMGuideAreaWyndon:
            return @"Follow the main avenue from Route 10. The stadium is north, the hotel is on the west side and the park is east. Check in at the stadium for the semifinals. Marnie uses Liepard, Toxicroak and Scrafty Lv. 47, Morpeko Lv. 48 and Gigantamax Grimmsnarl Lv. 49. Hop uses Dubwool and Corviknight Lv. 48, Pincurchin and Snorlax Lv. 47, and the Lv. 49 starter weak to yours.\n\n"
                @"After the semifinals, head to the hotel, then follow Piers to the station plaza. After Rose Tower, return to the stadium for the finals against Bede, Nessa, Allister and Raihan. Bede’s Fairy team finishes with Hatterene. Bring Grass or Electric for Nessa and Dark or Ghost for Allister. Against Raihan, plan for weather changes and Dynamax Duraludon. Follow the story through the Weald and Hammerlocke before returning for Leon.";
        case DMGuideAreaRoseTower:
            return @"Follow Piers from the hotel to the monorail plaza. Search for Eric with his back to you near the wall, then among the people and by the booth. Defeat him each time and take the monorail to Rose Tower.\n\n"
                @"Check the tower courtyard for items. Fight the staff in the lobby, then ride the lift with Hop and battle the staff pairs at each stop. Ground or Fighting moves help against their Steel types. At the top, Oleana uses Froslass, Tsareena and Salazzle Lv. 50, Milotic Lv. 51 and Gigantamax Garbodor Lv. 52.";
        case DMGuideAreaPostwick:
            return @"Collect your Bag from your bedroom, then follow Hop to his house on the east side of town. Speak to his mum and take the north road to meet Leon at Wedgehurst Station. Return with Leon to choose your partner. The next morning, meet Hop outside his house for your first battle.\n\n"
                @"When you hear trouble on the way home, follow Hop through the broken fence on the southwest path into the Slumbering Weald. After Leon brings you back, stop at home to speak to your mum before taking Route 1 again.\n\n"
                @"During the Champion Cup interruption, meet Sonia in Postwick before returning to the Weald. After becoming Champion, return home for Magnolia’s visit and go upstairs in Hop’s house to check Leon’s room.";
        case DMGuideAreaRoute1:
            return @"Follow the north road from Postwick to Wedgehurst. Stay on the road on your first trip with Hop. When Wooloo block the road on your return with a partner, take the detour through the grass on the east side.";
        case DMGuideAreaWeald:
            return @"On your first visit, follow Hop west through the fog to look for Wooloo. Fight or run from the early grass encounters, and speak to Hop if your partner needs healing. In Shield, keep taking turns when the red Pokémon appears to advance the scene.\n\n"
                @"During the Champion Cup interruption, follow the path past the former fog barrier to the bridge and the shrine by the lake. Pick up the Rusted Shield at the altar, then go to Hammerlocke Stadium.\n\n"
                @"After becoming Champion, speak to Hop at the shrine. He has Dubwool and Corviknight Lv. 59, Pincurchin, Snorlax and Cramorant Lv. 58, and the Lv. 60 starter weak to yours. After Sonia gives you her book, face Shielbert and then visit the Wedgehurst lab.\n\n"
                @"After the rooftop encounters, speak to Sonia at the forest entrance for a shortcut to the shrine. In your last match Hop has Dubwool and Corviknight Lv. 69, Snorlax and Pincurchin Lv. 68, his starter Lv. 70, and Zacian Lv. 70. Finish the conversation for his rare League Card.";
        case DMGuideAreaPowerPlant:
            return @"During the Champion Cup crisis, take the lift down from Hammerlocke Stadium. Rose uses Escavalier, Ferrothorn and Perrserker Lv. 55, Klinklang Lv. 56 and Gigantamax Copperajah Lv. 57. Fire works especially well on Escavalier and Ferrothorn.\n\n"
                @"Heal before following Hop to the rooftop. Defeat the first form of Eternatus. In the next battle, take turns until Zacian and Zamazenta join in, then attack and throw a ball when prompted.\n\n"
                @"After the postgame stadium incidents, return to the lower corridor and defeat Shielbert. His Sirfetch’d, Bronzong, Falinks and Klinklang are all Lv. 64. Use the lift to go to the roof. Stop Zacian, then approach Zamazenta to catch it.";
        case DMGuideAreaBattleTower:
            return @"After the Champion Cup, return to the tower in Wyndon. Collect Type: Null and its Memories from the staff member on the left. Check the rental desk if you want a ready-made team. Register at the main counter for Singles with three Pokémon or Doubles with four. Battles use Lv. 50 rules. The lobby has BP shops, a TM seller and Hyper Training.";
        default: return @"";
    }
}

static NSArray<DMGuideActivity *> *towerCourtyardPickups(void) {
    return @[
        pickupAt(@"rose-tower.eerie-impulse", @"TM93 Eerie Impulse", NO,
            @"Look behind the sign in the courtyard before entering the tower."),
        pickupAt(@"rose-tower.cell-battery", @"Cell Battery", NO,
            @"Walk around the east side of the tower."),
        pickupAt(@"rose-tower.electric-seed", @"Electric Seed", NO,
            @"Walk around the west side of the tower."),
        pickupAt(@"rose-tower.rare-candy", @"Rare Candy", YES,
            @"Check the southwest corner of the tower courtyard."),
        pickupAt(@"rose-tower.pp-up", @"PP Up", YES,
            @"Check for a sparkle along the east side of the tower."),
        pickupAt(@"rose-tower.nugget", @"Nugget", YES,
            @"Check for a sparkle along the west side of the tower.")
    ];
}

static NSArray<DMGuideActivity *> *laterActivities(DMGuideArea area) {
    switch (area) {
        case DMGuideAreaMine2:
            return @[
                trainerWin(@"mine2.trainer-francis", @"Worker Francis",
                    @"From the Hulbury entrance, continue past Bede toward the Dusk Balls.", @"Carkol Lv. 21."),
                trainerWin(@"mine2.trainer-yvonne", @"Worker Yvonne",
                    @"Pass the first underground pool. Follow the main tunnel past the fishing branch to the Grip Claw.", @"Roggenrola Lv. 20, Timburr Lv. 21."),
                trainerWin(@"mine2.trainer-vincent", @"Rail Staff Vincent",
                    @"After the Team Yell double battle, keep right at the Soft Sand fork toward TM49.", @"Drilbur Lv. 22, Onix Lv. 23."),
                pickupAt(@"mine2.dusk-balls", @"Dusk Balls ×3", NO,
                    @"Follow the tunnel from the Hulbury entrance to Worker Francis."),
                pickupAt(@"mine2.grip-claw", @"Grip Claw", NO,
                    @"Follow the main tunnel past the first pool. Check beside Worker Yvonne."),
                pickupAt(@"mine2.sand-tomb", @"TM49 Sand Tomb", NO,
                    @"Look down the short branch to the right just past Rail Staff Vincent."),
                pickupAt(@"mine2.star-piece", @"Star Piece", YES,
                    @"Check the left side of the chamber beyond the Team Yell fight."),
                pickupAt(@"mine2.soft-sand", @"Soft Sand", YES,
                    @"At the fork before Rail Staff Vincent, take the left branch past the Stunfisk."),
                waterActivity(@"mine2.mud-shot", @"TM53 Mud Shot", @"Ride across the underground pool.",
                    @"Cross the underground pool to find the item ball.")
            ];
        case DMGuideAreaOutskirts:
            return @[
                trainerWin(@"outskirts.trainer-caroline", @"Madame Caroline",
                    @"Follow the trail west of the mine exit toward the bridge to Motostoke.", @"Yamper Lv. 22, Swoobat Lv. 24."),
                trainerWin(@"outskirts.trainer-raymond", @"Police Officer Raymond",
                    @"Look along the trail connecting the mine-side grass and the bridge into Motostoke.", @"Growlithe Lv. 23."),
                pickupAt(@"outskirts.amulet-coin", @"Amulet Coin", NO,
                    @"Look directly behind the sign at the fork west of the mine exit."),
                pickupAt(@"outskirts.great-balls", @"Great Balls ×3", NO,
                    @"Take the grassy trail south of the mine exit."),
                pickupAt(@"outskirts.pp-up", @"PP Up", YES,
                    @"Look by the rocks northwest of the sign."),
                activity(@"outskirts.feathers", @"Bridge feathers", @"Check the bridge for sparkles on return visits.",
                    @"Collect any feather sparkle along the bridge.")
            ];
        case DMGuideAreaNorthWild:
            return [@[
                pickupAt(@"north-wild.fire-stone", @"Fire Stone · Motostoke Riverbank", NO,
                    @"After crossing the bridge, turn toward Motostoke and check the southwest corner along the city wall."),
                pickupAt(@"north-wild.facade", @"TM39 Facade · Motostoke Riverbank", NO,
                    @"Head to the northwest part of the riverbank and check east of the Berry tree behind the large pipe."),
                waterActivity(@"north-wild.lake-stones", @"Evolution stones beyond the lake", @"Cross the Lake of Outrage to the standing stones.",
                    @"Cross the Lake of Outrage and check the outer side of each standing stone on the bluff. They can sparkle again on later days."),
                waterActivity(@"north-wild.low-sweep", @"TM75 Low Sweep", @"Look for the water detour in Bridge Field.",
                    @"Look for the small island in the large Bridge Field pond."),
                pickupAt(@"north-wild.water-stone", @"Water Stone · Bridge Field", NO,
                    @"Follow the Motostoke wall on the west side of Bridge Field and check near the wall."),
                pickupAt(@"north-wild.sun-stone", @"Sun Stone · Dusty Bowl", NO,
                    @"Go to the northwest end of the natural rock bridge and look behind the small pillar."),
                pickupAt(@"north-wild.moon-stone", @"Moon Stone · Dusty Bowl", NO,
                    @"Check where the long ridge of rock meets the north wall in the northeast of the basin."),
                pickupAt(@"north-wild.dawn-stone", @"Dawn Stone · Giant’s Cap", NO,
                    @"Check the southern slope of Giant’s Cap above the Dusty Bowl."),
                waterActivity(@"north-wild.cross-poison", @"TM73 Cross Poison", @"Look for the water detour in the Dusty Bowl.",
                    @"Ride to the small island in the northwest pond in the Dusty Bowl."),
                waterActivity(@"north-wild.shadow-claw", @"TM65 Shadow Claw", @"Cross the Lake of Outrage.",
                    @"Ride to the shelf of land at the north end of the lake and check by the tree."),
                waterActivity(@"north-wild.focus-sash", @"Focus Sash pickup", @"Cross the Lake of Outrage.",
                    @"Look by the southwest rock wall on the far bluff."),
                waterActivity(@"north-wild.assault-vest", @"Assault Vest pickup", @"Cross the Lake of Outrage.",
                    @"Look by the northeast tree on the far bluff."),
                activity(@"north-wild.yamask-evolution", @"Evolve Galarian Yamask at the stone arch",
                    @"Bring Galarian Yamask from Route 6 to the Dusty Bowl.",
                    @"Have Yamask take at least 49 HP of damage from opposing attacks without fainting, then walk beneath the large natural stone arch in the Dusty Bowl to evolve it into Runerigus."),
                activity(@"north-wild.rally", @"Try a Rotom Rally", @"Talk to a Watt Trader after obtaining the Rotom Bike.",
                    @"Choose a course, ride through the balloons, and finish a run."),
                activity(@"north-wild.rally-thunder-wave", @"Rotom Rally · TM14 Thunder Wave", @"Finish a Rotom Rally course.",
                    @"After your first finish, talk to the Rallyist at the goal for TM14."),
                activity(@"north-wild.rally-volt-switch", @"Rotom Rally · TM80 Volt Switch", @"Beat 20,000 points in one run.",
                    @"Pick a longer course and hit as many balloons as you can. Talk to the Rallyist at the goal for TM80."),
                activity(@"north-wild.rally-fast-ball", @"Rotom Rally · Fast Ball reward", @"Finish 11 courses in total.",
                    @"Repeat any course and talk to the Rallyist at the goal to record the reward event."),
                activity(@"north-wild.bike-turbo", @"Upgrade the Rotom Bike’s turbo", @"Ask a Watt Trader to improve your bike.",
                    @"The three upgrades cost 1,000 W, 3,000 W and 5,000 W. Each shortens the time between boosts."),
                cyclingOutfitActivity(),
                activity(@"north-wild.nursery-taxi", @"Bridge Field Nursery Flying Taxi stop", @"Speak to the Nursery worker in Bridge Field.",
                    @"Talk to the Nursery worker to add this Nursery to your Flying Taxi destinations."),
                activity(@"north-wild.nursery-deposit", @"Leave two Pokémon at the Bridge Field Nursery", @"Speak to the worker near the Digging Duo.",
                    @"Leave two compatible Pokémon and explore the Wild Area. Return to the worker to pick up an Egg when one is ready."),
                hatchEggActivity(),
                activity(@"north-wild.digging-duo", @"Try the Digging Duo", @"Look for the brothers near the Bridge Field Nursery.",
                    @"Pay 500 Watts per run. The skill brother can find rarer items and all four fossils. The stamina brother usually digs up more items in a run.")
            ] arrayByAddingObjectsFromArray:wildAreaSharedActivities()];
        case DMGuideAreaHammerlocke:
            return @[
                activity(@"hammerlocke.ball-guy", @"Meet Ball Guy", @"Look in the stadium lobby.", @"Talk to Ball Guy for a Level Ball."),
                activity(@"hammerlocke.sonia-lock", @"Ask Sonia about the locked door", @"Check in at Hammerlocke Stadium during the postgame stadium incidents.",
                    @"Speak to Sonia near the elevator and ask about the Energy Plant’s locked door."),
                activity(@"hammerlocke.soothe-bell", @"The friendship house", @"Find the red door on the first house east of the stadium.", @"Speak to the girl at the back for a Soothe Bell."),
                activity(@"hammerlocke.friendship-ribbon", @"Best Friends Ribbon", @"Bring a Pokémon with maximum friendship.",
                    @"Show it to the boy in the red-door house east of the stadium."),
                activity(@"hammerlocke.effort-ribbon", @"Effort Ribbon", @"Bring a Pokémon with 510 total base points.",
                    @"Show it to the woman on the sofa in the red-door house east of the stadium."),
                activity(@"hammerlocke.weather-gifts", @"Weather lessons and rewards", @"From the friendship house, head east to the middle house in the next group of three.",
                    @"Talk to the weather expert once per day for the Heat, Damp, Icy and Smooth Rocks and the Utility Umbrella bonus."),
                activity(@"hammerlocke.letter", @"Accept an old letter", @"Take the stairs near the station to the courtyard with the Poké Ball statue.", @"Find Paula by the wall and accept her letter. The recipient, Frank, lives in the southern house in Ballonlea."),
                activity(@"hammerlocke.letter-return", @"Return to the letter’s sender", @"Come back after delivering the letter in Ballonlea.", @"Check where Paula was standing for the Reaper Cloth."),
                activity(@"hammerlocke.mr-focus", @"Mr. Focus’s challenge", @"Try the house immediately west of the central Pokémon Center.", @"Defeat Brian’s Cottonee Lv. 2 for a Focus Sash. Bring a multi-hit move to get past its own Focus Sash."),
                activity(@"hammerlocke.trade", @"A trade near the vault", @"Bring a Toxel.", @"Trade your Toxel for Togepi with the woman across from the vault entrance."),
                activity(@"hammerlocke.applin", @"Help a boy on the west side", @"Bring an Applin to the boy near the west exit.", @"Applin can be in your party or Boxes. Agree to lend it to him for the conversation. The Shield reward is a Sweet Apple."),
                daily(@"hammerlocke.cafe", @"Battle Café", @"Find the café west of the central Pokémon Center.", @"Battle the café master and check this off for today."),
                activity(@"hammerlocke.pledge-tutor", @"Pledge move tutor", @"Take the stairs near the Route 6 exit down to the moat.", @"Bring a Pokémon from Grookey’s line for Grass Pledge, Scorbunny’s or Charmander’s line for Fire Pledge, or Sobble’s line for Water Pledge. The tutor offers Silvally Grass Pledge."),
                pickupAt(@"hammerlocke.strawberry-sweet", @"Strawberry Sweet", NO,
                    @"Check southwest of the Poké Ball statue on the east side near the station."),
                pickupAt(@"hammerlocke.wise-glasses", @"Wise Glasses", NO,
                    @"Search east of the Poké Ball statue near the station."),
                pickupAt(@"hammerlocke.hyper-potions", @"Hyper Potions ×2", NO,
                    @"Look behind the pillar northwest of the salon."),
                pickupAt(@"hammerlocke.muscle-band", @"Muscle Band", NO,
                    @"Check the east edge of the court in front of the western Pokémon Center."),
                activity(@"hammerlocke.charm", @"TM29 Charm pickup", @"Check the steps outside the vault.",
                    @"Climb the outside stairs at the vault and check the south wall on the upper terrace."),
                pickupAt(@"hammerlocke.nugget", @"Nugget", YES,
                    @"Look behind the sign by the second flowerpot on the north side."),
                pickupAt(@"hammerlocke.dire-hit", @"Dire Hit", YES,
                    @"Check the corner east of the Pokémon Center by the Wild Area entrance."),
                pickupAt(@"hammerlocke.rare-candy", @"Rare Candy", YES,
                    @"Search the corner northeast of the Poké Ball statue near the station."),
                pickupAt(@"hammerlocke.super-repel", @"Super Repel", YES,
                    @"Check at the base of the pillar northwest of the salon."),
                pickupAt(@"hammerlocke.x-attacks", @"X Attacks ×2", YES,
                    @"Look just outside the western Pokémon Center.")
            ];
        case DMGuideAreaRoute6:
            return [fossilRecipeActivities() arrayByAddingObjectsFromArray:@[
                trainerWin(@"route6.trainer-anita", @"Beauty Anita",
                    @"Follow the path beyond the Team Yell bridge to the grass above the Ultra Balls.", @"Clefairy Lv. 29, Clefable Lv. 30."),
                trainerWin(@"route6.trainer-iwan", @"Medical Team Iwan and Evelyn",
                    @"Continue west from Anita along the lower path to the pair of ladders.", @"Pawniard Lv. 31, Togetic Lv. 31."),
                trainerWin(@"route6.trainer-diane", @"Backpacker Diane",
                    @"Climb out of the lower route via the left ladder and look by the ledge with Light Clay.", @"Sawk Lv. 31."),
                trainerWin(@"route6.trainer-nicola", @"Model Nicola",
                    @"Take the right ladder from Diane’s level and look east of the Rare Bone rocks.", @"Skorupi Lv. 30, Pawniard Lv. 30."),
                trainerWin(@"route6.trainer-ruth", @"Backpacker Ruth",
                    @"At the stone arch, descend the outer right ladder to the ledge with the Berry tree.", @"Throh Lv. 31."),
                trainerWin(@"route6.trainer-duncan", @"Artist Duncan",
                    @"Pass through the rock arch near the end of Route 6 toward Stow-on-Side.", @"Koffing Lv. 29, Sudowoodo Lv. 31."),
                campsiteTaxiStop(@"route6.campsite-taxi", @"Find the tent on the upper paths near Cara Liss."),
                pickupAt(@"route6.ultra-balls", @"Ultra Balls ×3", NO,
                    @"Drop to the ledge south of Beauty Anita after the first stretch of grass."),
                pickupAt(@"route6.light-clay", @"Light Clay", NO,
                    @"Climb the left ladder on the west side and check the ledge by Backpacker Diane."),
                pickupAt(@"route6.dig", @"TM15 Dig", NO,
                    @"Search just east of the tent on the upper trail."),
                pickupAt(@"route6.steel-wing", @"TM30 Steel Wing", NO,
                    @"Use the outer right ladder from the stone arch. Drop from Ruth’s ledge and go left."),
                pickupAt(@"route6.rare-bones", @"Rare Bones ×2", YES,
                    @"Check among the rocks west of Model Nicola."),
                pickupAt(@"route6.rare-candy", @"Rare Candy", YES,
                    @"Descend to the lower fishing pond and check the rock by the Trainer Tips sign."),
                pickupAt(@"route6.fossilized-fish", @"Fossilized Fish ×2", YES,
                    @"Look by the west side of the rock south of the camp, near Cara Liss.")
            ]];
        case DMGuideAreaStow:
            return @[
                activity(@"stow.fossils", @"A fossil gift", @"Talk to the man at the left table in the Pokémon Center.", @"In Shield he gives you two Fossilized Drakes."),
                activity(@"stow.trade", @"Rooftop trade", @"Bring a Maractus from Route 6.", @"Climb the western ladder to the roof with TM74. The man on the roof trades Maractus for Impidimp in Shield."),
                activity(@"stow.fly", @"A cabbie’s gift", @"Visit the house west of the stairs to the stadium.", @"Talk to the cabbie for TM06 Fly."),
                activity(@"stow.ball-guy", @"Meet Ball Guy", @"Look in the stadium lobby.", @"Speak to Ball Guy for a Heavy Ball."),
                daily(@"stow.bargain", @"Market bargain", @"Check the right-hand stall for today’s offer.", @"Speak to the bargain seller to see the daily item."),
                daily(@"stow.buyer", @"Market buyer", @"Check the other stall for today’s wanted item.", @"Ask what the buyer is looking for. Sell it if you have one to spare."),
                activity(@"stow.beast-ball", @"A Champion’s market gift", @"Return after becoming Champion.", @"Talk to the man at the right-hand stall for a Beast Ball."),
                pickupAt(@"stow.dusk-stone", @"Dusk Stone", NO,
                    @"Walk behind the Pokémon Center and check the corner."),
                pickupAt(@"stow.cracked-pot", @"Cracked Pot", NO,
                    @"Climb the ladder to the right of the stadium stairs to reach the roof."),
                activity(@"stow.phony-polteageist", @"Collect Phony Form Polteageist", @"Look for Sinistea in Glimwood Tangle.",
                    @"Use a Cracked Pot on Phony Form Sinistea. Climb the ladder to the right of the stadium stairs for the rooftop pickup, or check the bargain stall."),
                activity(@"stow.antique-polteageist", @"Collect Antique Form Polteageist", @"Look for Sinistea with an authenticity mark under its cup.",
                    @"Use a Chipped Pot on Antique Form Sinistea. Check the daily bargains at the right-hand market stall for this item."),
                pickupAt(@"stow.rocky-helmet", @"Rocky Helmet", NO,
                    @"Take the ladders down to the lower tier on the south side of town."),
                pickupAt(@"stow.venoshock", @"TM74 Venoshock", NO,
                    @"Climb the western ladder to the roof with the Maractus trader."),
                pickupAt(@"stow.x-sp-atk", @"X Sp. Atk ×2", YES,
                    @"Check the ground just left of the Bronzong."),
                pickupAt(@"stow.rare-bones", @"Rare Bones ×3", YES,
                    @"Take the southern ladders down and check the bags on the lower tier."),
                pickupAt(@"stow.metal-coat", @"Metal Coat", YES,
                    @"Use the western ladder and look for a sparkle on the roof near the trader."),
                pickupAt(@"stow.max-revive", @"Max Revive", YES,
                    @"Check the left edge of the first landing up the mural stairs.")
            ];
        case DMGuideAreaGlimwood:
            return @[
                trainerWin(@"glimwood.trainer-derek", @"Cook Derek",
                    @"At the first crossroads from Stow-on-Side, take the west path by the Bright Powder branch.", @"Milcery Lv. 33, Sinistea Lv. 33, Shiinotic Lv. 34."),
                trainerWin(@"glimwood.trainer-robert", @"Daring Couple Robert and Jacqueline",
                    @"Follow the east branch, then bend north to the pair near the branch for TM24.", @"Ninetales Lv. 34, Kirlia Lv. 34."),
                trainerWin(@"glimwood.trainer-judy", @"Madame Judy",
                    @"From the couple, follow the side path south toward the ledges for Luminous Moss and TM56.", @"Indeedee Lv. 33 ×2."),
                pickupAt(@"glimwood.bright-powder", @"Bright Powder", NO,
                    @"Take the first west fork. The path south of Cook Derek leads to the item."),
                pickupAt(@"glimwood.big-root", @"Big Root", NO,
                    @"Take the first east fork and look near the large tree root."),
                pickupAt(@"glimwood.hyper-potions", @"Hyper Potions ×2", NO,
                    @"Near the Ballonlea exit, check the path to the southwest."),
                pickupAt(@"glimwood.u-turn", @"TM56 U-turn", NO,
                    @"Follow the side path past Madame Judy to the ledge at its end."),
                pickupAt(@"glimwood.snore", @"TM24 Snore", NO,
                    @"From the double battle with Robert and Jacqueline, take the west path to its dead end."),
                pickupAt(@"glimwood.full-heals", @"Full Heals ×2", YES,
                    @"Check for a sparkle just east of the first crossroads."),
                pickupAt(@"glimwood.luminous-moss", @"Luminous Moss", YES,
                    @"Check the sparkle on the ledge along Madame Judy’s side path.")
            ];
        case DMGuideAreaBallonlea:
            return @[
                activity(@"ballonlea.letter", @"Deliver Paula’s letter", @"Bring the Old Letter from Hammerlocke.", @"Give the letter to Frank in the southern house for a Choice Scarf. Then return to Paula’s spot in Hammerlocke for the Reaper Cloth."),
                activity(@"ballonlea.fire-outfit", @"An outfit request", @"A man by the woodpile near the southern house wants to see fiery clothes.", @"Wear the Fire-type Tracksuit Jacket and speak to him for TM78 Acrobatics. Buy the Fire Uniform at a stadium uniform shop to get the jacket."),
                activity(@"ballonlea.revenge", @"Gift in the northern house", @"Visit the house nearer the stadium arch.", @"In Shield, the older woman offers TM42 Revenge."),
                activity(@"ballonlea.eviolite", @"Battle in the northern house", @"Speak to Pokémon Breeder Elena in the same house as the TM gift.", @"Defeat her Dottler Lv. 30 for an Eviolite. It already holds one, so plan for increased Defense and Special Defense."),
                activity(@"ballonlea.ball-guy", @"Meet Ball Guy", @"Look in the stadium lobby.", @"Speak to Ball Guy for a Love Ball."),
                activity(@"ballonlea.trade", @"A trade in the stadium", @"Bring a Galarian Yamask.", @"Trade with the child near the counter for Unovan Yamask. It evolves into Cofagrigus at Lv. 34."),
                pickupAt(@"ballonlea.rest", @"TM21 Rest", NO,
                    @"Look by the tall green mushrooms northeast of the Pokémon Center."),
                pickupAt(@"ballonlea.big-mushrooms", @"Big Mushrooms ×2", YES,
                    @"Check the orange mushrooms between the two houses."),
                pickupAt(@"ballonlea.balm-mushroom", @"Balm Mushroom", YES,
                    @"Look by the pink mushrooms on the ledge east of the Pokémon Center.")
            ];
        case DMGuideAreaRoute7:
            return @[
                trainerWin(@"route7.trainer-mila", @"Model Mila",
                    @"Past Hop, go south of the clump of trees with the hidden Balm Mushroom.", @"Ribombee Lv. 35, Vespiquen Lv. 36."),
                trainerWin(@"route7.trainer-bruce", @"Cabbie Bruce",
                    @"At the fork blocked by Team Yell, go north toward the Route 8 arch.", @"Corvisquire Lv. 35, Rufflet Lv. 36."),
                trainerWin(@"route7.trainer-caden", @"Gentleman Caden",
                    @"When the east side opens, look between Renee’s camp and the Route 9 Tunnel.", @"Doublade Lv. 44, Passimian Lv. 44, Polteageist Lv. 44."),
                campsiteTaxiStop(@"route7.campsite-taxi", @"Enter the east half through the Route 9 Tunnel from Outer Spikemuth."),
                pickupAt(@"route7.quick-balls", @"Quick Balls ×3", NO,
                    @"Check the grass east of the Berry tree near the Route 8 entrance."),
                pickupAt(@"route7.ether", @"Ether", YES,
                    @"Look by the rock east of the bridge from Hammerlocke, south of Mila."),
                pickupAt(@"route7.balm-mushroom", @"Balm Mushroom", YES,
                    @"Check between the trees northeast of the first Hop battle spot."),
                activity(@"route7.assurance", @"TM58 Assurance", @"Enter the east half from Outer Spikemuth.", @"Look against the railing by the east bridge, southeast of Renee’s camp."),
                activity(@"route7.safety-goggles", @"Safety Goggles", @"Enter the east half from Outer Spikemuth.", @"Take the downhill trail beside the east bridge and check opposite the Berry tree."),
                activity(@"route7.pp-up", @"Hidden PP Up", @"Enter the east half from Outer Spikemuth.", @"Check the rocks northwest of the Route 9 Tunnel entrance.")
            ];
        case DMGuideAreaRoute8:
            return @[
                trainerWin(@"route8.trainer-joanna", @"Doctor Joanna",
                    @"Take the first east branch down the ladder and follow the path.", @"Roselia Lv. 36, Hattrem Lv. 36."),
                trainerWin(@"route8.trainer-barbara", @"Backpacker Barbara",
                    @"After the Falinks tunnels, take the northwest stairs toward the hidden Big Nugget.", @"Dreepy Lv. 36, Vullaby Lv. 37."),
                trainerWin(@"route8.trainer-charles", @"Musician Charles",
                    @"Return to the fork from Barbara and follow the northeast path.", @"Togedemaru Lv. 37."),
                trainerWin(@"route8.trainer-jordan", @"Colleagues Jordan and Alison",
                    @"At the arch to Steamdrift Way, detour east to the camp.", @"Excadrill Lv. 36, Lucario Lv. 37, Hippowdon Lv. 36, Perrserker Lv. 37."),
                trainerWin(@"route8.trainer-bobby", @"Police Officer Bobby",
                    @"Follow Steamdrift Way through the snow to the last stretch before Circhester.", @"Arcanine Lv. 37, Boltund Lv. 37."),
                campsiteTaxiStop(@"route8.campsite-taxi", @"At the Circhester tunnel junction, follow the path east past the Trainers."),
                pickupAt(@"route8.shiny-stone", @"Shiny Stone", NO,
                    @"Climb the ladder east of Joanna and take the south branch to the ledge."),
                pickupAt(@"route8.smart-strike", @"TM96 Smart Strike", NO,
                    @"Take the west ladder near the Trainer Tips sign to the raised ledge."),
                pickupAt(@"route8.hyper-potions", @"Hyper Potions ×3", NO,
                    @"Check the dead end between the two ladders on the east side of the ruins."),
                pickupAt(@"route8.luxury-balls", @"Luxury Balls ×3", NO,
                    @"At the Falinks tunnels, explore the ramp-like ledge to the east."),
                pickupAt(@"route8.max-revive", @"Max Revive", NO,
                    @"Past the Falinks area, take the southwest turn into the dead end."),
                pickupAt(@"route8.kings-rock", @"King’s Rock", NO,
                    @"Climb down the ladder east of Charles and look in the small alcove."),
                pickupAt(@"route8.brick-break", @"TM43 Brick Break", NO,
                    @"After Charles, climb back up by the Crustle and follow the narrow west path."),
                pickupAt(@"route8.terrain-extender", @"Terrain Extender", NO,
                    @"Take the narrow trail leading east from Lisa’s camp."),
                pickupAt(@"route8.x-defense", @"X Defense ×3", YES,
                    @"Check the corner at the top of the first set of stairs."),
                pickupAt(@"route8.elixir", @"Elixir", YES,
                    @"At the middle of the ruins, check by the wheelbarrow between the sloped ledges."),
                pickupAt(@"route8.pixie-plate", @"Pixie Plate", YES,
                    @"Check the recess south of the first Falinks tunnel."),
                pickupAt(@"route8.big-nugget", @"Big Nugget", YES,
                    @"Climb the stairs north of Backpacker Barbara and check by the rock at the end."),
                pickupAt(@"route8.nugget", @"Nugget", YES,
                    @"Check between the Falinks tunnels near the northeast corner of the ruins."),
                pickupAt(@"route8.star-pieces", @"Star Pieces ×2 · Steamdrift Way", YES,
                    @"Look in the northwest corner of the first grass patch in Steamdrift Way.")
            ];
        case DMGuideAreaCirchester:
            return @[
                activity(@"circhester.rock-tomb", @"A gift behind the Pokémon Center", @"Visit the first house behind the Center.", @"Speak to the man inside for TM48 Rock Tomb in Shield."),
                activity(@"circhester.trade", @"A trade at the food stand", @"Bring a Vanillish.", @"Speak to the man by the food stand to trade for Sawk in Shield."),
                activity(@"circhester.detective", @"The missing Berries", @"Visit the first upstairs room left of the elevator in Hotel Ionia’s east building.", @"Talk to the detective and inspect the suspects. Reveal the culprit by pointing out the Skwovet. Return to the detective for the Wide Lens."),
                activity(@"circhester.screech", @"Hotel gift · TM16 Screech", @"Use the elevator in Hotel Ionia’s east building.", @"Speak to the hiker on the right side of the upstairs hall for TM16 Screech."),
                activity(@"circhester.fake-tears", @"Last room on the right", @"Use the elevator in Hotel Ionia’s east building.", @"Speak to the man in the last room on the right for TM47 Fake Tears."),
                activity(@"circhester.catching-charm", @"Meet the director", @"Visit the last upstairs room to the left in Hotel Ionia’s west building.", @"Talk to the director to receive the Catching Charm."),
                activity(@"circhester.ball-guy", @"Meet Ball Guy", @"Look in the stadium lobby.", @"Speak to Ball Guy for a Moon Ball."),
                activity(@"circhester.morimoto", @"Morimoto’s challenge", @"Return as Champion and take the elevator in Hotel Ionia’s west building.",
                    @"Find Morimoto in the second guest room from the left. In doubles he brings Cursola, Grapploct, Stonjourner, Dragapult, Coalossal and Snorlax, all Lv. 65. Bring Water or Ground for Coalossal and a Fighting move for Snorlax."),
                activity(@"circhester.oval-charm", @"Receive the Oval Charm", @"Win Morimoto’s first challenge at Hotel Ionia.",
                    @"Accept his Oval Charm in the west hotel. Keeping it in your Bag helps you find Eggs faster at either Nursery."),
                daily(@"circhester.morimoto-rematch", @"Morimoto rematch", @"Return after your first win.", @"Win the daily rematch and check it off for today."),
                activity(@"circhester.shiny-charm", @"Show the completed Galar Pokédex", @"Return to the director after completing the regional Pokédex.", @"Visit the west hotel’s director to collect the completion rewards, including the Shiny Charm."),
                activity(@"circhester.draco-meteor", @"A move tutor at the bath", @"Look on the west side of the Hero’s Bath.", @"Bring a Dragon-type Pokémon or Silvally to learn Draco Meteor."),
                pickupAt(@"circhester.icicle-spear", @"TM51 Icicle Spear", NO,
                    @"Look on the east side of the Hero’s Bath."),
                pickupAt(@"circhester.full-heals", @"Full Heals ×3", YES,
                    @"Check the recess on the left just before leaving southeast for Route 9."),
                pickupAt(@"circhester.poke-doll", @"Poké Doll", YES,
                    @"Check down the east stairs in front of the Hero’s Bath."),
                pickupAt(@"circhester.snowball", @"Snowball", YES,
                    @"Check down the west stairs in front of the Hero’s Bath."),
                pickupAt(@"circhester.lemonade", @"Lemonade", YES,
                    @"Look along the west side of the Hero’s Bath near the tutor."),
                pickupAt(@"circhester.x-sp-atk", @"X Sp. Atk ×2", YES,
                    @"Check the snow pile against the wall west of the stadium.")
            ];
        case DMGuideAreaRoute9:
            return @[
                trainerWin(@"route9.trainer-harriet", @"Fisher Harriet",
                    @"Check the west bank of the first bridge out of Circhester.", @"Barraskewda Lv. 39, Lanturn Lv. 39."),
                trainerWin(@"route9.trainer-zoe", @"Dancer Zoe",
                    @"Follow the trail south of the first grass patch before Circhester Bay.", @"Galarian Darumaka Lv. 39, Bellossom Lv. 39."),
                trainerWin(@"route9.trainer-carter", @"Black Belt Carter",
                    @"After unlocking Water Mode, head west across the bay to the beach by the hidden Black Belt.", @"Grapploct Lv. 41."),
                trainerWin(@"route9.trainer-reece", @"Black Belt Reece",
                    @"Ride southeast from the Dive beach, then east to the shore below Stephan’s camp.", @"Sawk Lv. 41, Throh Lv. 41."),
                trainerWin(@"route9.trainer-marina", @"Fisher Marina",
                    @"Cross the bay to Stephan’s camp, then head southeast past the coastal grass.", @"Qwilfish Lv. 39, Pyukumuku Lv. 40."),
                trainerWin(@"route9.trainer-jacob", @"Swimmer Jacob",
                    @"From Marina, ride southeast past the ice where Grapploct circles, then turn west.", @"Cloyster Lv. 39."),
                trainerWin(@"route9.trainer-logan", @"Swimmer Logan",
                    @"Ride west along the south side of the bay toward the secluded shore with TM22.", @"Wishiwashi Lv. 40, Wailord Lv. 40."),
                trainerWin(@"route9.trainer-scarlett", @"Swimmer Scarlett",
                    @"Ride to the private beach with the Berry tree on the east side of the bay.", @"Remoraid Lv. 39, Octillery Lv. 40, Mantine Lv. 40."),
                trainerWin(@"route9.trainer-layla", @"Swimmer Layla",
                    @"Look on the beach at the south end of the bay, near the trail to Outer Spikemuth.", @"Toxapex Lv. 39."),
                trainerWin(@"route9.trainer-owen", @"Music Crew Owen and Andrea",
                    @"After the bay, take the west branch through Outer Spikemuth near the Berry tree.", @"Toxtricity Lv. 41, Maractus Lv. 41."),
                activity(@"route9.bike-water-mode", @"Unlock Water Mode", @"Look for the doctor on the way into Circhester Bay.",
                    @"Help the doctor fend off Team Yell. He upgrades the Rotom Bike so you can ride across water."),
                waterActivity(@"route9.campsite-taxi", @"Campsite Flying Taxi stop", @"Find Stephan on the large landmass in the bay.",
                    @"Talk to Stephan at the camp, then check for the Flying Taxi icon on the Town Map."),
                waterActivity(@"route9.dive", @"A secluded beach gift", @"Look for the secluded beach in Circhester Bay.",
                    @"Ride west to the secluded beach with the two swimmers. Speak to the woman there for TM45 Dive."),
                pickupAt(@"route9.max-potion", @"Max Potion", NO,
                    @"Check the north side of the first grass patch south of the bridge from Circhester."),
                waterActivity(@"route9.avalanche", @"TM64 Avalanche · pickup", @"Ride up the river on northern Route 9.",
                    @"From the first bridge south of Circhester, ride northwest along the river. Turn south near the western bridge and continue past the Glalie."),
                waterPickup(@"route9.zoom-lens", @"Zoom Lens", NO, @"Ride to the small island immediately west of the doctor."),
                waterPickup(@"route9.protector", @"Protector", NO, @"Ride to the secluded shore east of the Trainer Tips sign, near the Circhester Bay sign."),
                waterPickup(@"route9.max-revive", @"Max Revive", NO, @"Ride west from the southbound water crossing to the island just south of the inlet where a Pearl sparkles."),
                waterPickup(@"route9.dive-balls", @"Dive Balls ×3", NO, @"Check the southwest corner of the secluded beach with the TM45 gift."),
                waterPickup(@"route9.rock-slide", @"TM22 Rock Slide", NO, @"Ride west past Swimmer Logan to the secluded shore northwest of the Outer Spikemuth trail."),
                pickupAt(@"route9.scope-lens", @"Scope Lens · Outer Spikemuth", NO,
                    @"At the bottom of the slope from the bay, search the west clearing in the grass."),
                waterPickup(@"route9.pearl-string", @"Pearl String", YES, @"Check the east side of the canal northeast of Fisher Marina."),
                waterPickup(@"route9.ice-stone", @"Ice Stone", YES, @"Check the west side of the canal northeast of Fisher Marina."),
                waterPickup(@"route9.never-melt-ice", @"Never-Melt Ice", YES, @"Check the clearing in the grass west of Fisher Marina."),
                waterPickup(@"route9.rare-candy", @"Rare Candy", YES, @"Follow the short dead-end path west of Stephan’s camp."),
                waterPickup(@"route9.black-belt", @"Black Belt", YES, @"Ride to the west shore and check near Black Belt Carter."),
                waterPickup(@"route9.normal-gem", @"Normal Gem", YES, @"Check the rock on the east edge of the cove just north of the Outer Spikemuth shore."),
                waterPickup(@"route9.pp-up", @"PP Up", YES, @"Check the water off the private beach with the Berry tree on the east side."),
                waterPickup(@"route9.max-elixir", @"Max Elixir", YES, @"Check between the three rocks near the south shore leading to Outer Spikemuth."),
                pickupAt(@"route9.dire-hits", @"Dire Hits ×3 · Outer Spikemuth", YES,
                    @"Check the shipping crates up the slope toward the front gate."),
                pickupAt(@"route9.guard-spec", @"Guard Specs ×3 · Outer Spikemuth", YES,
                    @"Check the clearing by the pallets in the grass south of the front gate."),
                waterActivity(@"route9.pearls", @"Hidden pearls around the bay", @"Search the inlets, canal and south shore.",
                    @"Find two Pearls and three Big Pearls. Check both inlets north of the Max Revive, the canal north of the Pearl String and the shore on each side of Swimmer Layla.")
            ];
        case DMGuideAreaSpikemuth:
            return @[
                activity(@"spikemuth.trade", @"A trade near the stage", @"Bring an Obstagoon.", @"Trade with the Team Yell Grunt by the stall near the stage to receive Kantonian Mr. Mime."),
                activity(@"spikemuth.marnie", @"Marnie’s first rematch", @"Return to the stage after your final Weald battle with Hop.",
                    @"Marnie brings Liepard, Toxicroak and Scrafty Lv. 59, and Morpeko and Grimmsnarl Lv. 60. Use Fairy against Scrafty and Psychic against Toxicroak. Win for her rare League Card."),
                daily(@"spikemuth.marnie-daily", @"Marnie’s daily rematch", @"Return after your first exhibition win.", @"Win the daily rematch and check it off for today."),
                pickupAt(@"spikemuth.max-revive", @"Max Revive", NO,
                    @"Follow the main street partway to the stage and look for the item ball."),
                pickupAt(@"spikemuth.choice-specs", @"Choice Specs", NO,
                    @"After defeating Piers, look south of the stage.")
            ];
        case DMGuideAreaRoute10:
            return @[
                trainerWin(@"route10.trainer-graham", @"Doctor Graham",
                    @"From White Hill Station, head north past the first grass patch.", @"Gardevoir Lv. 45."),
                trainerWin(@"route10.trainer-douglas", @"Hiker Douglas",
                    @"Continue north from Graham toward the first fork.", @"Steelix Lv. 45, Mudsdale Lv. 45."),
                trainerWin(@"route10.trainer-ronald", @"Office Worker Ronald",
                    @"Take the northeast trail at the fork beyond Douglas.", @"Weavile Lv. 45, Claydol Lv. 45."),
                trainerWin(@"route10.trainer-geoffrey", @"Cabbie Geoffrey",
                    @"Follow the path west from the nook with the hidden Comet Shard.", @"Corviknight Lv. 45, Flygon Lv. 46."),
                trainerWin(@"route10.trainer-harper", @"Postman Harper",
                    @"Follow the snowy trail uphill past Geoffrey.", @"Pelipper Lv. 46, Noctowl Lv. 46."),
                trainerWin(@"route10.trainer-donald", @"Hiker Donald",
                    @"Head north from Tristan’s camp toward the final climb.", @"Gigalith Lv. 46, Rhydon Lv. 46."),
                trainerWin(@"route10.trainer-glenn", @"Gentleman Glenn",
                    @"Continue up the main slope past Donald.", @"Darmanitan Lv. 46, Falinks Lv. 46, Grapploct Lv. 46."),
                trainerWin(@"route10.trainer-gillian", @"Interviewers Gillian and Cam",
                    @"Look near the top of the final climb before the road drops toward Wyndon.", @"Heliolisk Lv. 46, Noivern Lv. 47, Klinklang Lv. 46, Togedemaru Lv. 47."),
                campsiteTaxiStop(@"route10.campsite-taxi", @"Look west at the fork before the final climb to Wyndon."),
                pickupAt(@"route10.max-revive", @"Max Revive", NO,
                    @"Search the grass southeast of White Hill Station."),
                pickupAt(@"route10.power-herb", @"Power Herb", NO,
                    @"Take the southern spur from the upper trail east of Tristan’s camp."),
                pickupAt(@"route10.stomping-tantrum", @"TM98 Stomping Tantrum", NO,
                    @"Before descending into Wyndon, go east to the clifftop."),
                pickupAt(@"route10.x-attacks", @"X Attacks ×2", YES,
                    @"Check by the cart west of the door at White Hill Station."),
                pickupAt(@"route10.comet-shard", @"Comet Shard", YES,
                    @"Take the northeast fork past Ronald and check the rock in the corner."),
                pickupAt(@"route10.pp-up", @"PP Up", YES,
                    @"Check just west of Tristan’s camp.")
            ];
        case DMGuideAreaWyndon:
            return @[
                activity(@"wyndon.trade", @"A trade across the bridge", @"Bring a Frosmoth to the artist in the first turquoise building across the bridge.", @"Trade your Frosmoth for Duraludon."),
                activity(@"wyndon.rotom-catalog", @"A battle across the bridge", @"Try the second house from the north end of the eastern street.",
                    @"Defeat Isaac’s Mow, Wash and Heat Rotom, all Lv. 34, for the Rotom Catalog. Use it from Key Items on a Rotom in your party. Find Rotom at the Lake of Outrage in rain or thunderstorms."),
                activity(@"wyndon.ball-guy", @"Meet Ball Guy", @"Look in the stadium lobby.", @"Speak to Ball Guy for a Dream Ball."),
                daily(@"wyndon.cafe", @"Battle Café", @"The café offers one challenge per day.", @"Battle the café master and check it off for today."),
                activity(@"wyndon.champion-tournament", @"Win a Champion Tournament", @"Return to the stadium after becoming Champion.", @"Enter the tournament at reception and win the final."),
                daily(@"wyndon.tournament-reward", @"Daily tournament reward", @"The first tournament victory each day earns a Wishing Piece.", @"Win a tournament at Wyndon Stadium and collect the Wishing Piece."),
                activity(@"wyndon.starter-tutor", @"A move tutor in the park", @"Look near the court and bring an eligible fully evolved starter.", @"Bring Rillaboom for Frenzy Plant, Cinderace or Charizard for Blast Burn, or Inteleon for Hydro Cannon."),
                pickupAt(@"wyndon.grassy-seed", @"Grassy Seed", NO,
                    @"Go to the central lawn of the park on the east side of town."),
                pickupAt(@"wyndon.air-balloon", @"Air Balloon", NO,
                    @"Check by the phone booth outside the Rose of the Rondelands hotel."),
                pickupAt(@"wyndon.max-revive", @"Max Revive", YES,
                    @"Search the corner west of the south Pokémon Center."),
                pickupAt(@"wyndon.rare-candy", @"Rare Candy", YES,
                    @"Check the southern end of the central lawn in the east park."),
                pickupAt(@"wyndon.balm-mushroom", @"Balm Mushroom", YES,
                    @"Search at the northeast side of the east park."),
                pickupAt(@"wyndon.nugget", @"Nugget", YES,
                    @"Follow the west waterfront walkway and look near its middle."),
                pickupAt(@"wyndon.black-sludge", @"Black Sludge", YES,
                    @"Check the waterfront path on the west side of town."),
                pickupAt(@"wyndon.big-nugget", @"Big Nugget", YES,
                    @"Check just west of the Flying Taxi outside the hotel."),
                pickupAt(@"wyndon.x-speed", @"X Speed", YES,
                    @"Check west of the vendors outside Wyndon Stadium."),
                pickupAt(@"wyndon.x-sp-atk", @"X Sp. Atk ×2", YES,
                    @"Check east of the steps outside Wyndon Stadium.")
            ];
        case DMGuideAreaRoseTower:
            return towerCourtyardPickups();
        case DMGuideAreaPostwick:
            return @[
                activity(@"postwick.hop-first-win", @"Win your first battle with Hop", @"After choosing your partner, meet Hop outside his house the next morning.",
                    @"Hop sends out a Lv. 3 Wooloo, then a Lv. 5 starter weak to yours. Use the type move your partner learns after Wooloo: Branch Poke with Grookey, Ember with Scorbunny or Water Gun with Sobble."),
                activity(@"postwick.sonia-revives", @"Receive Sonia’s Max Revives", @"Return to Postwick during the Champion Cup interruption.",
                    @"Meet Sonia in Postwick. Check this off when she gives you three Max Revives before you enter the Slumbering Weald."),
                activity(@"postwick.charmander", @"A gift in Leon’s room", @"Return to Hop’s house after becoming Champion.", @"Go upstairs and pick up the Poké Ball in Leon’s room for Charmander."),
                activity(@"postwick.master-ball", @"A visit from Magnolia", @"Return home after the Champion Cup.", @"Talk to Professor Magnolia when she visits and check off the gift once you receive the Master Ball.")
            ];
        case DMGuideAreaRoute1:
            return @[
                activity(@"route1.first-catch", @"Catch a Pokémon on Route 1", @"Explore the grass once catching is available.", @"Check this off after you catch a Pokémon on this route. A Pokémon obtained elsewhere does not count."),
                activity(@"route1.potion", @"Potion pickup", @"Look between the patches of tall grass.", @"Pick up the Potion between the tall-grass patches on the detour toward Wedgehurst."),
                activity(@"route1.paralyze-heals", @"Paralyze Heals ×2", @"Continue past the Potion on the grassy detour toward Wedgehurst.",
                    @"On the grass path east of the road, continue toward Wedgehurst and collect the visible item ball with two Paralyze Heals.")
            ];
        case DMGuideAreaWeald:
            return @[
                activity(@"weald.sonia-book", @"Receive Sonia’s Book", @"Return to the shrine after becoming Champion.",
                    @"Meet Hop at the shrine. After battling him, talk with Sonia to receive her book."),
                activity(@"weald.sonia-shrine", @"Check in with Sonia at the shrine", @"Return after the Energy Plant rooftop encounters.",
                    @"Sonia can escort you from the entrance to the shrine. Talk to her again near Hop before his final battle. She can take you back to the entrance if you need time to prepare."),
                activity(@"weald.postgame-epilogue", @"Finish the Weald epilogue", @"Meet Hop at the shrine after the rooftop encounters.",
                    @"Take on Hop’s final battle and finish the conversation that follows."),
                waterPickup(@"weald.life-orb", @"Life Orb", NO, @"Beyond the fog barrier, take the east fork and ride south along the stream to the small bank below the grass."),
                pickupAt(@"weald.misty-seed", @"Misty Seed", NO,
                    @"Beyond the fog barrier, take the east fork and then the left branch to the dead end."),
                pickupAt(@"weald.mental-herb", @"Mental Herb", NO,
                    @"Take the far-west path beyond the fog barrier and look just past the fallen trunk."),
                activity(@"weald.phantom-force", @"TM86 Phantom Force", @"Return after the fog barrier lifts during the Champion Cup interruption.",
                    @"Beyond the area where you first passed out, follow the northeast branch across a fallen log to the TM."),
                pickupAt(@"weald.smoke-ball", @"Smoke Ball", NO,
                    @"Follow the east branch of the west trail and check the path just north of the fallen log."),
                pickupAt(@"weald.full-restore", @"Full Restore", YES,
                    @"Check the middle of the first deep forest grass patch beyond the former fog barrier."),
                pickupAt(@"weald.elixir", @"Elixir", YES,
                    @"Cross the fallen log on the way to TM86. Check the grass immediately beyond the log.")
            ];
        case DMGuideAreaPowerPlant:
            return @[
                activity(@"power-plant.eternatus", @"Register Eternatus", @"Reach the roof during the Champion Cup story.",
                    @"Fight Eternatus alongside Zacian and Zamazenta and catch it when prompted."),
                activity(@"power-plant.zamazenta", @"Register Zamazenta", @"Return to the roof after the postgame stadium incidents.",
                    @"Stop the rampaging Zacian, then approach Zamazenta. Bring Poké Balls for the Lv. 70 encounter."),
            ];
        case DMGuideAreaBattleTower:
            return [@[
                activity(@"battle-tower.type-null", @"Receive Type: Null", @"Talk to the League staff member after becoming Champion.", @"Accept Type: Null in the lobby. The staff member also offers the memory items used by Silvally."),
                activity(@"battle-tower.memories", @"Collect Silvally’s Memories", @"Visit the League staff member on the left side of the lobby after becoming Champion.",
                    @"The Type: Null gift includes all 17 Memories. Level up Type: Null with high friendship to evolve it into Silvally. Give Silvally a Memory to change its type and the type of Multi-Attack."),
                activity(@"battle-tower.judge", @"Unlock the Judge function", @"Reach Poké Ball Tier in Singles or Doubles.",
                    @"Finish the promotion battle and return to the lobby. Use the Judge function in your Boxes after the receptionist unlocks it."),
                activity(@"battle-tower.singles-master", @"Reach Master Ball Tier in Singles", @"Register for Single Battles in the lobby.",
                    @"Climb the Singles ranks through Ultra Ball Tier to the Master Ball promotion."),
                activity(@"battle-tower.doubles-master", @"Reach Master Ball Tier in Doubles", @"Register for Double Battles in the lobby.",
                    @"Climb the Doubles ranks through Ultra Ball Tier to the Master Ball promotion."),
                activity(@"battle-tower.master-ribbon", @"Tower Master Ribbon", @"Face Leon in Master Ball Tier.",
                    @"Defeat Leon in Master Ball Tier with your own team to earn this Ribbon for your participants."),
                activity(@"battle-tower.hyper-training", @"Try Hyper Training", @"Bring a Lv. 100 Pokémon to the Battle Tower after becoming Champion.",
                    @"Speak to the Hyper Training attendant. A Bottle Cap trains one stat, and a Gold Bottle Cap trains all eligible stats."),
                activity(@"battle-tower.rental-team", @"Try a rental team", @"Speak to the rental counter.", @"Borrow a team and try it in Singles or Doubles."),
                activity(@"battle-tower.first-win", @"Win a Battle Tower battle", @"Return after becoming Champion and register in the lobby.", @"Win a Singles or Doubles battle. You can keep entering to earn Battle Points.")
            ] arrayByAddingObjectsFromArray:towerCourtyardPickups()];
        default: return @[];
    }
}
