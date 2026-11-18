#pragma once
#import "shield_guide.h"

typedef struct {
    NSUInteger slot;
    DMGuideArea area;
    NSString *key;
    NSString *name;
    NSString *hint;
    NSString *directions;
} ShieldLeagueCard;

// The four Bea and Gordie slots belong to the Sword story. Slots remain unrenumbered.
static const ShieldLeagueCard shieldLeagueCards[] = {
    {0, DMGuideAreaMotostoke, @"motostoke.hop-card", @"Hop’s League Card",
        @"Meet Hop before leaving for Route 3.", @"Finish Hop’s battle near the west exit from Motostoke to receive his card."},
    {1, DMGuideAreaWeald, @"weald.hop-rare-card", @"Hop’s rare League Card",
        @"Return to the Slumbering Weald at the end of the postgame story.", @"Finish the final battle with Hop and speak with him after the battle."},
    {2, DMGuideAreaBallonlea, @"ballonlea.marnie-card", @"Marnie’s League Card",
        @"Head into Ballonlea Stadium during the Gym Challenge.", @"Speak to Marnie in the stadium lobby before Opal’s Gym challenge."},
    {3, DMGuideAreaSpikemuth, @"spikemuth.marnie-rare-card", @"Marnie’s rare League Card",
        @"Return after your final battle with Hop in the Slumbering Weald.", @"Defeat Marnie in her first exhibition match and collect her card."},
    {4, DMGuideAreaTurffield, @"turffield.milo-card", @"Milo’s League Card",
        @"Meet Sonia at the geoglyph overlook.", @"Follow Yamper to the hill in Turffield and speak to Sonia before the Gym."},
    {5, DMGuideAreaTurffield, @"turffield.milo-rare-card", @"Milo’s rare League Card",
        @"Return to Turffield Stadium during the Champion’s stadium investigation.", @"Help Milo calm the Dynamax Pokémon, then finish the conversation at the stadium."},
    {6, DMGuideAreaHulbury, @"hulbury.nessa-card", @"Nessa’s League Card",
        @"Look for Nessa by the lighthouse.", @"Speak to Nessa at the lighthouse before challenging the Gym."},
    {7, DMGuideAreaHulbury, @"hulbury.nessa-rare-card", @"Nessa’s rare League Card",
        @"Return to Hulbury Stadium during the Champion’s stadium investigation.", @"Help Nessa calm the Dynamax Pokémon, then speak to her."},
    {8, DMGuideAreaMotostoke, @"motostoke.kabu-card", @"Kabu’s League Card",
        @"See Marnie at the Budew Drop Inn before the Fire Gym.", @"Finish the evening battle at the inn and speak to Marnie in the lobby the next morning."},
    {9, DMGuideAreaMotostoke, @"motostoke.kabu-rare-card", @"Kabu’s rare League Card",
        @"Return to Motostoke Stadium during the Champion’s stadium investigation.", @"Help Kabu calm the Dynamax Pokémon and finish his postbattle conversation."},
    {12, DMGuideAreaStow, @"stow.allister-card", @"Allister’s League Card",
        @"Speak with Opal after battling Hop.", @"Finish Hop’s battle in Stow-on-Side and stay to speak with Opal on the approach to the stadium."},
    {13, DMGuideAreaStow, @"stow.allister-rare-card", @"Allister’s rare League Card",
        @"Return to Stow-on-Side Stadium during the Champion’s stadium investigation.", @"Help Allister put a stop to the Dynamax incident, then finish his conversation."},
    {14, DMGuideAreaRoute6, @"route6.opal-card", @"Opal’s League Card",
        @"Stay near Hop after the Team Yell encounter.", @"Defeat Team Yell on Route 6 and speak to Opal before continuing toward Stow-on-Side."},
    {15, DMGuideAreaBallonlea, @"ballonlea.opal-rare-card", @"Opal’s rare League Card",
        @"Return to Ballonlea Stadium during the Champion’s stadium investigation.", @"Defeat Bede at the stadium. Opal gives you her card after the battle."},
    {18, DMGuideAreaCirchester, @"circhester.melony-card", @"Melony’s League Card",
        @"Meet Hop at Circhester Stadium.", @"Talk to Hop inside the stadium before the Ice Gym challenge."},
    {19, DMGuideAreaCirchester, @"circhester.melony-rare-card", @"Melony’s rare League Card",
        @"Return to Circhester Stadium during the Champion’s stadium investigation.", @"Help Melony calm the Dynamax Pokémon, then speak to her."},
    {20, DMGuideAreaSpikemuth, @"spikemuth.piers-card", @"Piers’s League Card",
        @"Look for Marnie past the Pokémon Center.", @"After entering Spikemuth with Marnie, head east from the Pokémon Center and speak to her before the Gym."},
    {21, DMGuideAreaPowerPlant, @"power-plant.piers-rare-card", @"Piers’s rare League Card",
        @"Finish the legendary encounter on the Energy Plant roof.", @"Catch Zamazenta in the postgame and finish the conversation with Piers about Sordward and Shielbert."},
    {22, DMGuideAreaHammerlocke, @"hammerlocke.raihan-card", @"Raihan’s League Card",
        @"Meet Raihan by the Hammerlocke vault.", @"Talk to Raihan at the vault entrance during your first visit."},
    {23, DMGuideAreaHammerlocke, @"hammerlocke.raihan-rare-card", @"Raihan’s rare League Card",
        @"Return to Hammerlocke Stadium during the Champion’s stadium investigation.", @"Help Raihan calm the Dynamax Pokémon and stay for the conversation afterward."},
    {24, DMGuideAreaMotostoke, @"motostoke.leon-card", @"Leon’s League Card",
        @"Follow Sonia into the Pokémon Center on your first visit.", @"Finish Sonia’s introduction to Rotomi to receive Leon’s card."},
    {25, DMGuideAreaBattleTower, @"battle-tower.leon-card", @"Leon’s rare League Card",
        @"Reach Poké Ball Tier.", @"Defeat Leon in the promotion battle and collect his rare League Card."},
    {26, DMGuideAreaHulbury, @"hulbury.rose-card", @"Rose’s League Card",
        @"Look for Oleana outside Hulbury Stadium after winning the Water Badge.", @"Speak to Oleana before going to the Captain’s Table to meet Chairman Rose."},
    {27, DMGuideAreaGalarMine, @"galar-mine.rose-card", @"Rose’s rare League Card",
        @"Revisit the first Galar Mine after becoming Champion.", @"From Route 3, take the second west branch off the tracks, toward TM26 Scary Face. Speak to Oleana at the end."},
    {28, DMGuideAreaMine2, @"mine2.bede-card", @"Bede’s League Card",
        @"Look for Bede near the entrance from Hulbury.", @"Defeat Bede during your first trip through Galar Mine No. 2."},
    {29, DMGuideAreaBallonlea, @"ballonlea.bede-rare-card", @"Bede’s rare League Card",
        @"Return to Ballonlea Stadium during the Champion’s stadium investigation.", @"Defeat Bede at the stadium and finish the conversation afterward."},
    {30, DMGuideAreaMotostoke, @"motostoke.ball-guy-card", @"Ball Guy’s League Card",
        @"Come back after you become Champion.", @"Talk to Ball Guy in front of Motostoke Stadium."},
};
enum { shieldLeagueCardCount = sizeof(shieldLeagueCards) / sizeof(shieldLeagueCards[0]) };
