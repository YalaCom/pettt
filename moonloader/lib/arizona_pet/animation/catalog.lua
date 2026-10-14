-- Three real poses. Semantic fallbacks are explicit, not fictional animations.
local M={
    idle={frames={{'open',3.4}},loop=true,priority=0},
    blink={frames={{'open',.06},{'closed',.12},{'open',.06}},priority=1,next='idle'},
    sleep={frames={{'closed',3}},loop=true,priority=100},
    pet={frames={{'closed',.8},{'open',.4}},priority=40,next='idle'},
    wake={frames={{'closed',.2},{'open',.8}},priority=101,next='idle'},
}
for _,name in ipairs({'look','yawn','stretch','eat','refuse_food','hug','wash','shake','play','jump','dance',
    'happy','joy','laugh','delight','surprised','sad','offended','irritated','angry','furious','scared','shy','love',
    'sleepy','bored','welcome','beg_food','beg_sleep','celebrate','turn_away','cross_arms','walk'}) do
    M[name]={frames={{'open',1.5}},priority=(name=='offended' or name=='scared') and 70 or 30,
        next=name=='furious' and 'offended' or 'idle',fallback=true}
end
M.offended={frames={{'offended',2}},loop=true,priority=20}
M.angry={frames={{'offended',1.5}},priority=70,next='offended'}
M.furious={frames={{'offended',1.5}},priority=70,next='offended',fallback=true}
return M
