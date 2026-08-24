alter table public.scores
  drop constraint scores_score_range,
  add constraint scores_score_range check (score between 0 and 220590);

insert into private.stage_score_limits (completed_stage, max_score)
values
  (1, 6450),
  (2, 11020),
  (3, 14380),
  (4, 17320),
  (5, 24170),
  (6, 28750),
  (7, 33000),
  (8, 38580),
  (9, 41020),
  (10, 47520),
  (11, 52510),
  (12, 56410),
  (13, 64880),
  (14, 72440),
  (15, 78120),
  (16, 83710),
  (17, 87300),
  (18, 96970),
  (19, 101010),
  (20, 107760),
  (21, 117540),
  (22, 125730),
  (23, 137330),
  (24, 146290),
  (25, 148980),
  (26, 158840),
  (27, 165460),
  (28, 171300),
  (29, 183760),
  (30, 194770),
  (31, 203700),
  (32, 214070),
  (33, 220590)
on conflict (completed_stage) do update
set max_score = excluded.max_score;
