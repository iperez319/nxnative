#pragma once
#import "shield_guide.h"

enum { fireMissionScore = 0x32C4F443, fireBadge = 0x7F29D95E };

typedef struct {
    DMGuideArea area;
    NSString *missionKey;
    NSString *badgeKey;
    uint32_t missionFlag;
    uint32_t badgeFlag;
    NSString *badge;
    NSString *leader;
    NSString *missionHint;
    NSString *mission;
    NSString *battle;
} ShieldGym;

static const ShieldGym shieldGyms[] = {
    {DMGuideAreaTurffield, @"turffield.gym-mission", @"turffield.gym-badge", 0x9203329A, 0x299E4801,
        @"Grass Badge", @"Milo", @"Visit the stadium after meeting Sonia at the geoglyph.",
        @"Herd the Wooloo through each gate. Steer around Yamper or stop to battle their Trainers. Samuel has Gossifleur Lv. 16, Mark has Budew Lv. 16 and Oddish Lv. 17, and Leah has Bounsweet and Oddish Lv. 17.",
        @"Milo uses Gossifleur Lv. 19 and Dynamax Eldegoss Lv. 20. Bring Fire, Flying, or Bug moves and save Dynamax for Eldegoss."},
    {DMGuideAreaHulbury, @"hulbury.gym-mission", @"hulbury.gym-badge", 0x890D1CF9, 0xFF80169D,
        @"Water Badge", @"Nessa", @"Speak to Nessa at the lighthouse first.",
        @"Use the colored switches to move the water barriers. Open Route directions for the sequence. Julia has Tympole Lv. 21, Heather has Krabby and Corphish Lv. 20, and Lynn has Remoraid Lv. 20 and Chewtle Lv. 21.",
        @"Nessa uses Goldeen Lv. 22, Arrokuda Lv. 23 and Dynamax Drednaw Lv. 24. Grass or Electric moves help. Drednaw is especially weak to Grass."},
    {DMGuideAreaMotostoke, @"motostoke.gym-mission", @"motostoke.gym-badge", 0x626D6B24, fireBadge,
        @"Fire Badge", @"Kabu", @"Return after meeting Kabu in Galar Mine No. 2 and resting at the inn.",
        @"Earn five points. Catch a wild Vulpix, Sizzlipede or Litwick for two points or knock one out for one. Your opponent can defeat the wild Pokémon first, so bring quick status moves and useful balls.",
        @"Kabu uses Ninetales and Arcanine Lv. 25, then Gigantamax Centiskorch Lv. 27. Water helps throughout, and Rock hits Centiskorch especially hard."},
    {DMGuideAreaStow, @"stow.gym-mission", @"stow.gym-badge", 0x3148B754, 0x71BFDED1,
        @"Ghost Badge", @"Allister", @"Head to the stadium after meeting Hop and Opal in Stow-on-Side.",
        @"Rotate the left stick to steer the cup, using the springy walls to turn. Clive has two Pumpkaboo and Phantump Lv. 31. Roy has Haunter and Drifblim Lv. 33. Lynne has Galarian Corsola Lv. 32.",
        @"Allister uses Galarian Yamask and Mimikyu Lv. 34, Cursola Lv. 35 and Gigantamax Gengar Lv. 36. Dark or Ghost moves help. Break Mimikyu’s Disguise with a small hit, then save Dynamax for Gengar."},
    {DMGuideAreaBallonlea, @"ballonlea.gym-mission", @"ballonlea.gym-badge", 0x5B946783, 0x8BCBBCDE,
        @"Fairy Badge", @"Opal", @"Check in at Ballonlea Stadium after talking to Marnie.",
        @"Beat Annette (Spritzee and Slurpuff Lv. 34), Teresa (Swirlix and Aromatisse Lv. 34) and Theodora (Morgrem and Gardevoir Lv. 35). Answer Poison or Steel, then Annette, then omelets.",
        @"Opal uses Galarian Weezing and Mawile Lv. 36, Togekiss Lv. 37 and Gigantamax Alcremie Lv. 38. Use Steel or Poison against Fairy, with a Fire move for Mawile. Answer The Wizard, purple, and 16."},
    {DMGuideAreaCirchester, @"circhester.gym-mission", @"circhester.gym-badge", 0xDF3DB17F, 0xFE5A7D5F,
        @"Ice Badge", @"Melony", @"Check in at Circhester Stadium after talking to Hop.",
        @"Use the detector’s vibration to avoid holes. Move slowly in the final foggy room. Lewis has Snom Lv. 38, Liana has Cloyster Lv. 38, Alexander has Beartic Lv. 39, and Micah has Avalugg Lv. 39.",
        @"Melony uses Frosmoth and Galarian Darmanitan Lv. 40, Eiscue Lv. 41 and Gigantamax Lapras Lv. 42. Fire or Rock works well on Frosmoth. Special moves bypass Eiscue’s Ice Face. Bring an Electric or Fighting move for Lapras."},
    {DMGuideAreaSpikemuth, @"spikemuth.gym-mission", @"spikemuth.gym-badge", 0xC28A76F1, 0xC90B46C2,
        @"Dark Badge", @"Piers", @"Follow Marnie through the alternate entrance.",
        @"Follow the main street past Team Yell. The singles opponents have Galarian Linoone, Thievul and Scrafty Lv. 42, then Weavile Lv. 43. The final pair uses Liepard and Drapion Lv. 43.",
        @"Piers uses Scrafty Lv. 44, Malamar and Skuntank Lv. 45, and Obstagoon Lv. 46. Use Fairy against Scrafty, Bug against Malamar, Ground against Skuntank and Fighting against Obstagoon. There is no Dynamax here."},
    {DMGuideAreaHammerlocke, @"hammerlocke.gym-mission", @"hammerlocke.gym-badge", 0x143E0946, 0x375FD6A8,
        @"Dragon Badge", @"Raihan", @"Return after the Spikemuth Gym and look for Raihan at the vault.",
        @"Win three doubles matches. Sebastian leads Pelipper and Sliggoo, Camilla leads Ninetales and Turtonator, and Aria leads Abomasnow and Hakamo-o. All six are Lv. 45.",
        @"Raihan uses Gigalith and Sandaconda Lv. 46, Flygon Lv. 47 and Gigantamax Duraludon Lv. 48. Plan a pair for sand and doubles. Ice helps against Flygon, and Ground or Fighting helps against Duraludon."},
};
enum { shieldGymCount = sizeof(shieldGyms) / sizeof(shieldGyms[0]) };
