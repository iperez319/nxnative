#include "../Sources/DmControlMath.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
    int32_t x,y;
    dm_control_stick(0,0,60,0,1,&x,&y); assert(!x && !y);
    dm_control_stick(5,0,60,0.1,1,&x,&y); assert(!x && !y);
    dm_control_stick(48,0,60,0.1,1,&x,&y); assert(x==32767 && y==0);
    dm_control_stick(0,-100,60,0.1,1,&x,&y); assert(x==0 && y==32767);
    dm_control_stick(0,100,60,0.1,1,&x,&y); assert(y==-32767);
    int32_t previous=0;
    for (int n=0;n<100;n++) { dm_control_stick(n,0,60,0.1,1,&x,&y); assert(x>=previous && x<=32767); previous=x; }
    for (int angle=0;angle<360;angle++) {
        dm_control_stick(100*cos(angle*M_PI/180),100*sin(angle*M_PI/180),60,0.1,2,&x,&y);
        assert(hypot(x,y)<=32768);
    }
    dm_control_stick(NAN,1,60,0.1,1,&x,&y); assert(!x && !y);
    assert(dm_control_bound(NAN,1,0.25,2)==1);
    assert(dm_control_bound(-10,1,0.25,2)==0.25);
    assert(dm_control_bound(10,1,0.25,2)==2);
    assert(dm_control_dpad(0,0,48)==0);
    assert(dm_control_dpad(40,0,48)==(1ull<<14));
    assert(dm_control_dpad(40,-40,48)==((1ull<<14)|(1ull<<13)));
    assert(dm_control_dpad(-40,40,48)==((1ull<<12)|(1ull<<15)));
    puts("PASS: stick dead zone, saturation, monotonic response, radial bounds and D-pad diagonals");
}
