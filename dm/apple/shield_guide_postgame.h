#pragma once
#import "shield_guide.h"

enum {
    turffieldDebrief = 0x37AFE5F0,
    hulburyIncident = 0x3A68EA36, motostokeIncident = 0x3A6B2A3F,
    hammerlockeIncident = 0x3F680229, stowIncident = 0x3F64E8A0,
    ballonleaIncident = 0x3F6D5BBB, circhesterIncident = 0x3F6A4232,
    wealdEpilogue = 0xE4136279,
};

typedef struct {
    DMGuideArea area;
    NSString *key;
    uint32_t work;
    NSString *hint;
    NSString *directions;
} ShieldPostgameStadium;

static const ShieldPostgameStadium postgameStadiums[] = {
    {DMGuideAreaTurffield, @"turffield.postgame-stadium", 0,
        @"Start here after Sonia’s detector briefing.", @"Help Milo with the Dynamax Tsareena. Bring Fire, Flying, or Poison coverage. Stay for the stadium debrief before checking Hulbury and Motostoke."},
    {DMGuideAreaHulbury, @"hulbury.postgame-stadium", hulburyIncident,
        @"Return to Hulbury Stadium when Sonia reports two incidents.", @"Help Nessa take down the Dynamax Gyarados. Electric moves are especially effective. Finish the stadium conversation."},
    {DMGuideAreaMotostoke, @"motostoke.postgame-stadium", motostokeIncident,
        @"Return to Motostoke Stadium when Sonia reports two incidents.", @"Help Kabu take down the Dynamax Torkoal. Bring a Rock or Ground move if its sun weakens Water attacks. Finish the stadium conversation."},
    {DMGuideAreaHammerlocke, @"hammerlocke.postgame-stadium", hammerlockeIncident,
        @"Return after the second briefing at the Wedgehurst lab.", @"Help Raihan take down the Dynamax Haxorus. Try Fairy or Ice attacks and speak with Raihan afterward."},
    {DMGuideAreaStow, @"stow.postgame-stadium", stowIncident,
        @"Return after the second briefing at the Wedgehurst lab.", @"Help Allister take down the Dynamax Dusknoir with Dark or Ghost attacks. Speak with Allister afterward."},
    {DMGuideAreaBallonlea, @"ballonlea.postgame-stadium", ballonleaIncident,
        @"Return after the second briefing at the Wedgehurst lab.", @"Meet Opal and Bede in the stadium. Bede has Mawile and Gardevoir Lv. 61, Galarian Rapidash Lv. 62 and Hatterene Lv. 63. Bring Steel or Ghost coverage and a Fire move for Mawile. Finish the conversation afterward."},
    {DMGuideAreaCirchester, @"circhester.postgame-stadium", circhesterIncident,
        @"Return after the second briefing at the Wedgehurst lab.", @"Help Melony take down the Dynamax Froslass. Steel, Rock, Fire or Dark works well. Speak with Melony afterward."},
};
enum { postgameStadiumCount = sizeof(postgameStadiums) / sizeof(postgameStadiums[0]) };
