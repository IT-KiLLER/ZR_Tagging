# ZR_Tagging
Tagging plugin for CS:GO Zombie Reloaded<br />
<br />
Cvars:<br />
**sm_stamina_burncost** - def **40.0**, Stamina penalty applied when burned<br />
**sm_tagging_penalty** - def **25.0**, Stamina penalty applied when shot<br />
**sm_tagging_time** - def **1.5**, How long tagging lasts from being shot<br />
<br />
Things to note:<br />
* This incorporates Rules of _P burn_slow plugin. Please disable burn_slow.smx before testing to avoid conflicts<br />
* Disable regular tagging with sm_cvar mp_tagging_scale 100 to avoid conflicts<br />
* Increase sm_tagging_penalty if zombies are not slowed enough (movement speed) - def 25.0<br />
* Increase sm_tagging_time if you want them slowed for a longer duration - def 1.5s<br />
