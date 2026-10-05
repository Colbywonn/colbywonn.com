#!/usr/bin/perl
# Generates the seamless PCB-trace background tile used on wide screens (see the PCB block in
# assets/css/site.css). Usage:
#
#   perl _tools/pcbgen.pl OUT.svg [SEED] [WIDTH] [HEIGHT] [COLOR]
#
# The same seed always produces the same board; _tools/build-pcb.sh regenerates every page's tile.
#
# Layers, in routing order: a large focal chip beside the nav, smaller chips whose pad rows launch
# buses or fan out locally, two-pad passives and via arrays around the chips, long buses at mixed
# spacings, a few fat power traces, single wandering traces, then medium traces in the gaps.
# Buses bend at 45 degrees, fan apart at their ends and jog around vias; single traces sometimes
# carry a length-matching serpentine. One pad has lifted off the board. Collision checks wrap around the tile edges
# (a torus), and the content is drawn with 8 shifted copies, so traces leaving one edge re-enter
# the opposite one.
use strict;
use warnings;
use POSIX qw(floor);

my ($out, $seed, $W, $H, $color) = @ARGV;
die "usage: pcbgen.pl OUT.svg [SEED] [WIDTH] [HEIGHT] [COLOR]\n" unless $out;
$seed //= 7; $W //= 1600; $H //= 1200; $color //= '#eaeef5';
die "WIDTH and HEIGHT must be multiples of 50\n" if $W % 50 || $H % 50;
srand($seed);

# PITCH and TR are package variables so try_bus can vary them per bus with local()
our $PITCH = 12;    # bus trace spacing (centerline)
my  $GAP   = 8;     # clearance between unrelated copper edges
our $TR    = 1.5;   # trace half-width
my $VR    = 6;      # via outer radius
my $PR    = 7;      # pad collision radius
my $B     = 50;     # spatial hash bucket size
my ($NBX, $NBY) = (int($W / $B), int($H / $B));

my @dirs = ([1,0],[1,1],[0,1],[-1,1],[-1,0],[-1,-1],[0,-1],[1,-1]);
sub unit { my ($x, $y) = @{$dirs[$_[0] % 8]}; my $l = sqrt($x*$x + $y*$y); ($x/$l, $y/$l) }

# ---- geometry ----
sub pseg {  # point to segment distance
  my ($px,$py,$ax,$ay,$bx,$by) = @_;
  my ($dx,$dy) = ($bx-$ax, $by-$ay);
  my $l2 = $dx*$dx + $dy*$dy;
  my $t = $l2 ? (($px-$ax)*$dx + ($py-$ay)*$dy) / $l2 : 0;
  $t = 0 if $t < 0; $t = 1 if $t > 1;
  my ($qx,$qy) = ($ax + $t*$dx, $ay + $t*$dy);
  sqrt(($px-$qx)**2 + ($py-$qy)**2);
}
sub orient { my ($ax,$ay,$bx,$by,$cx,$cy) = @_; ($bx-$ax)*($cy-$ay) - ($by-$ay)*($cx-$ax) }
sub sdist {
  my ($a1,$a2,$b1,$b2,$c1,$c2,$d1,$d2) = @_;
  my $o1 = orient($a1,$a2,$b1,$b2,$c1,$c2); my $o2 = orient($a1,$a2,$b1,$b2,$d1,$d2);
  my $o3 = orient($c1,$c2,$d1,$d2,$a1,$a2); my $o4 = orient($c1,$c2,$d1,$d2,$b1,$b2);
  return 0 if $o1*$o2 < 0 && $o3*$o4 < 0;
  my @d = (pseg($a1,$a2,$c1,$c2,$d1,$d2), pseg($b1,$b2,$c1,$c2,$d1,$d2),
           pseg($c1,$c2,$a1,$a2,$b1,$b2), pseg($d1,$d2,$a1,$a2,$b1,$b2));
  my $m = $d[0]; for (@d) { $m = $_ if $_ < $m } $m;
}

# ---- world: items are [x1,y1,x2,y2,radius] in tile coords (may poke past the edges) ----
my @items;
my $OWNER = 0;   # while routing a component's own pads, its body outline (items tagged [5]) is ignored
my %hash;
sub buckets {
  my ($x1,$y1,$x2,$y2,$pad) = @_;
  my ($minx,$maxx) = $x1 < $x2 ? ($x1,$x2) : ($x2,$x1);
  my ($miny,$maxy) = $y1 < $y2 ? ($y1,$y2) : ($y2,$y1);
  my @k;
  for my $bx (floor(($minx-$pad)/$B) .. floor(($maxx+$pad)/$B)) {
    for my $by (floor(($miny-$pad)/$B) .. floor(($maxy+$pad)/$B)) {
      push @k, ($bx % $NBX) . ',' . ($by % $NBY);
    }
  }
  @k;
}
sub add_item { my $it = shift; push @items, $it; push @{$hash{$_}}, $#items for buckets(@$it[0..3], 0) }
sub clear {
  my $c = shift;
  my %seen;
  my $pad = $c->[4] + $VR + $GAP + 1;
  for my $k (buckets(@$c[0..3], $pad)) {
    for my $i (@{$hash{$k} || []}) {
      next if $seen{$i}++;
      my $it = $items[$i];
      next if $OWNER && defined $it->[5] && $it->[5] == $OWNER;
      for my $sx (-$W, 0, $W) { for my $sy (-$H, 0, $H) {
        my $d = sdist(@$c[0..3], $it->[0]+$sx, $it->[1]+$sy, $it->[2]+$sx, $it->[3]+$sy);
        return 0 if $d < $c->[4] + $it->[4] + $GAP;
      } }
    }
  }
  1;
}

# Offset a centerline polyline by o (miter joins); dirs[k] is the direction of segment k
sub offset_line {
  my ($pts, $ds, $o) = @_;
  my @r;
  for my $i (0 .. $#$pts) {
    my ($x, $y) = @{$pts->[$i]};
    my @n;
    if ($i == 0 || $i == $#$pts) {
      my ($ux,$uy) = unit($ds->[$i == 0 ? 0 : $#$ds]);
      @n = (-$uy*$o, $ux*$o);
    } else {
      my ($u1x,$u1y) = unit($ds->[$i-1]); my ($u2x,$u2y) = unit($ds->[$i]);
      my ($n1x,$n1y,$n2x,$n2y) = (-$u1y,$u1x,-$u2y,$u2x);
      my $den = 1 + $n1x*$n2x + $n1y*$n2y;
      @n = (($n1x+$n2x)/$den*$o, ($n1y+$n2y)/$den*$o);
    }
    push @r, [$x+$n[0], $y+$n[1]];
  }
  \@r;
}

my (@paths, @pathw, @vias, @pads);   # @pathw: each path's stroke width

sub pick { my @w = @_; my $t = 0; $t += $_->[1] for @w; my $r = rand($t); for (@w) { return $_->[0] if ($r -= $_->[1]) < 0 } $w[-1][0] }

# Routes one bus. Options: n (traces), d0 (start direction), sx/sy (start), pads (pad row at the
# start: 1 forces, 0 forbids, undef = random), seg [min,max] segment count, orth/diag [min,max]
# run lengths, minlen (shortest total centerline worth keeping), w (trace width), pitch (trace
# spacing), and the chances of fanned ends (fan), a via dodge (dodge) and a serpentine (meander).
sub try_bus {
  my %o = @_;
  local $TR = ($o{w} // 3) / 2;
  local $PITCH = $o{pitch} // 12;
  my $n = $o{n} // pick([1,3],[2,3],[3,3],[4,2],[5,1.5],[6,1]);
  my $d0 = $o{d0} // pick(map { [$_, $_ % 2 ? 2 : 3] } 0..7);
  my ($sx, $sy) = defined $o{sx} ? ($o{sx}, $o{sy}) : (4*int(rand($W/4)), 4*int(rand($H/4)));
  my ($smin, $smax) = @{$o{seg} // [3, 8]};
  my ($omin, $omax) = @{$o{orth} // [100, 500]};
  my ($dmin, $dmax) = @{$o{diag} // [24, 140]};
  my @pts = ([$sx,$sy]); my @ds;
  my $turn = 0;
  my $nseg = $smin + int(rand($smax - $smin + 1));
  my $geom;
  for my $k (0 .. $nseg-1) {
    my $ok = 0;
    for my $attempt (1..8) {
      my $d = $d0;
      my $t = $turn;
      if ($k > 0) {
        my $step = rand() < 0.5 ? 1 : -1;
        $t = $turn + $step; $t = $turn - $step if abs($t) > 2;
        $d = ($d0 + $t) % 8;
      }
      # Long straight runs, short 45-degree jogs; later attempts shorten the run so a bus can
      # still squeeze past its neighbours
      my $len = $d % 2 ? $dmin + 4*int(rand(($dmax-$dmin)/4 + 1)) : $omin + 4*int(rand(($omax-$omin)/4 + 1));
      $len = 4*int($len * (1 - 0.1*$attempt) / 4) if $attempt > 2;
      # Each bend pulls the inner traces' corners in by up to ~2.5px per trace; keep every run
      # long enough that wide buses never fold back on themselves
      my $minrun = 5*($n-1) + 8;
      $len = $minrun if $len < $minrun;
      my ($ux,$uy) = unit($d);
      my ($lx,$ly) = @{$pts[-1]};
      my @np = (@pts, [$lx + $ux*$len, $ly + $uy*$len]);
      my @nd = (@ds, $d);
      my $g = bus_geom(\@np, \@nd, $n);
      next unless all_clear($g);
      @pts = @np; @ds = @nd; $turn = $t; $geom = $g; $ok = 1;
      last;
    }
    last unless $ok;
  }
  return 0 unless $geom;
  my $total = 0; for my $i (1..$#pts) { $total += sqrt(($pts[$i][0]-$pts[$i-1][0])**2 + ($pts[$i][1]-$pts[$i-1][1])**2) }
  return 0 if $total < ($o{minlen} // 320);

  # Ends: the bus either fans out (traces peel off one by one to their own vias) or stops in a
  # staggered via row; the start can instead be a pad row when it leaves orthogonally
  my $padstart = $o{pads} // (($ds[0] % 2 == 0) && $n >= 2 && rand() < 0.45);
  my $fanp = $o{fan} // 0.6;
  my @lines = map { [ map { [@$_] } @$_ ] } @$geom;
  my @ends;
  unless ($n >= 2 && rand() < $fanp && fan_tails(\@lines, $ds[-1], $n, 1, \@ends)) {
    my ($ex,$ey) = unit($ds[-1]);
    for my $j (0 .. $n-1) {
      my $st = ($n > 1 && $j % 2) ? 14 : 0;
      my $l = $lines[$j];
      $l->[-1] = [$l->[-1][0] + $ex*$st, $l->[-1][1] + $ey*$st];
      push @ends, ['via', @{$l->[-1]}];
    }
  }
  if ($padstart) {
    push @ends, ['pad', @{$lines[$_][0]}, $ds[0], $_, $n] for 0 .. $n-1;
  } elsif (!($n >= 2 && rand() < $fanp && fan_tails(\@lines, $ds[0], $n, 0, \@ends))) {
    my ($bx,$by) = unit($ds[0]);
    for my $j (0 .. $n-1) {
      my $st = ($n > 1 && $j % 2) ? 14 : 0;
      my $l = $lines[$j];
      $l->[0] = [$l->[0][0] - $bx*$st, $l->[0][1] - $by*$st];
      push @ends, ['via', @{$l->[0]}];
    }
  }
  dodge(\@lines, $n, \@ends) if $n >= 2 && rand() < ($o{dodge} // 0.8);
  meander($lines[0]) if $n == 1 && rand() < ($o{meander} // 0.45);
  my @cand;
  for my $l (@lines) { push @cand, [@{$l->[$_-1]}, @{$l->[$_]}, $TR] for 1..$#$l }
  push @cand, [$_->[1], $_->[2], $_->[1], $_->[2], $_->[0] eq 'via' ? $VR : $PR] for @ends;
  return 0 unless all_clear_items(\@cand);
  # Ends of neighbouring traces must not touch each other either
  for my $a (0 .. $#ends) { for my $b ($a+1 .. $#ends) {
    my $d = sqrt(($ends[$a][1]-$ends[$b][1])**2 + ($ends[$a][2]-$ends[$b][2])**2);
    return 0 if $d > 0 && $d < 11.5 && ($ends[$a][0] eq 'via' || $ends[$b][0] eq 'via') && $d < 2*$VR - 0.5;
  } }
  add_item($_) for @cand;
  push @paths, $_ for @lines;
  push @pathw, (2*$TR) x @lines;
  # pads keep [x, y, dir, trace index in bus, bus size, index of their trace in @paths]
  for (@ends) { $_->[0] eq 'via' ? push(@vias, [$_->[1], $_->[2]]) : push(@pads, [@$_[1..5], $#paths - $_->[5] + 1 + $_->[4]]) }
  1;
}

sub local_ok {
  my ($cand, $local) = @_;
  for my $c (@$cand) { for my $l (@$local) {
    return 0 if sdist(@$c[0..3], @$l[0..3]) < $c->[4] + $l->[4] + 8;
  } }
  1;
}

# Fan one end of a bus out: outer traces peel off first with a 45-degree bend away from the bus
# centre, inner ones later and less far, so the traces spread apart without crossing; each ends
# at its own via. At the start end (atend = 0) the same thing happens walking backwards.
sub fan_tails {
  my ($lines, $dir, $n, $atend, $ends) = @_;
  my $d = $atend ? $dir : ($dir + 4) % 8;
  my ($ux, $uy) = unit($d);
  my @os = map { ($_ - ($n-1)/2) * $PITCH * ($atend ? 1 : -1) } 0 .. $n-1;
  my $rmax = ($n-1)/2;
  my (@tails, @local);
  for my $j (sort { abs($os[$b]) <=> abs($os[$a]) } 0 .. $n-1) {
    my $o = $os[$j];
    my $p = $atend ? $lines->[$j][-1] : $lines->[$j][0];
    my $r = $rmax - abs($o)/$PITCH;              # 0 for the outermost trace
    my $ok = 0;
    for my $try (1 .. 4) {
      my @t = ([@$p]);
      if (abs($o) < 1e-6) {
        my $L = 24 + 4*int(rand(20));
        push @t, [$p->[0] + $ux*$L, $p->[1] + $uy*$L];
      } else {
        my ($tx, $ty) = unit(($d + ($o > 0 ? 1 : -1)) % 8);
        my $L0 = 6 + $r*13;
        my $D  = 16 + ($rmax - $r)*14 + 4*int(rand(3));
        my $F  = 8 + 4*int(rand(16));
        my $a = [$p->[0] + $ux*$L0, $p->[1] + $uy*$L0];
        my $b = [$a->[0] + $tx*$D, $a->[1] + $ty*$D];
        push @t, $a, $b, [$b->[0] + $ux*$F, $b->[1] + $uy*$F];
      }
      my @c = map { [@{$t[$_-1]}, @{$t[$_]}, $TR] } 1 .. $#t;
      push @c, [@{$t[-1]}, @{$t[-1]}, $VR];
      next unless all_clear_items(\@c) && local_ok(\@c, \@local);
      push @local, @c; push @tails, [$j, \@t]; $ok = 1;
      last;
    }
    return 0 unless $ok;
  }
  for (@tails) {
    my ($j, $t) = @$_;
    my @t = @$t[1 .. $#$t];
    if ($atend) { push @{$lines->[$j]}, @t } else { unshift @{$lines->[$j]}, reverse @t }
    push @$ends, ['via', @{$t->[-1]}];
  }
  1;
}

# An outer trace of a bus jogs out around a via sitting on its path, then rejoins the bus
sub dodge {
  my ($lines, $n, $ends) = @_;
  my $j = rand() < 0.5 ? 0 : $n-1;
  my $l = $lines->[$j];
  my @segs = grep {
    my ($a, $b) = ($l->[$_-1], $l->[$_]);
    (abs($a->[0]-$b->[0]) < 0.01 || abs($a->[1]-$b->[1]) < 0.01) &&
      sqrt(($b->[0]-$a->[0])**2 + ($b->[1]-$a->[1])**2) >= 120
  } 1 .. $#$l;
  return unless @segs;
  my $k = $segs[int rand @segs];
  my ($a, $b) = ($l->[$k-1], $l->[$k]);
  my $len = sqrt(($b->[0]-$a->[0])**2 + ($b->[1]-$a->[1])**2);
  my ($ux, $uy) = (($b->[0]-$a->[0])/$len, ($b->[1]-$a->[1])/$len);
  my ($wx, $wy) = $j == 0 ? ($uy, -$ux) : (-$uy, $ux);   # away from the rest of the bus
  my $J = 14;
  my $s = 30 + rand($len - 120);
  my $p1 = [$a->[0] + $ux*$s, $a->[1] + $uy*$s];
  my $p2 = [$p1->[0] + ($ux+$wx)*$J, $p1->[1] + ($uy+$wy)*$J];
  my $p3 = [$p2->[0] + $ux*24, $p2->[1] + $uy*24];
  my $p4 = [$p3->[0] + ($ux-$wx)*$J, $p3->[1] + ($uy-$wy)*$J];
  my $v  = [$p1->[0] + $ux*($J+12), $p1->[1] + $uy*($J+12)];
  my @c = ([@$p1, @$p2, $TR], [@$p2, @$p3, $TR], [@$p3, @$p4, $TR], [@$v, @$v, $VR]);
  return unless all_clear_items(\@c);
  splice @$l, $k, 0, $p1, $p2, $p3, $p4;
  push @$ends, ['via', @$v];
}

# Length-matching serpentine: a square-wave meander spliced into one straight run of a trace
sub meander {
  my ($l) = @_;
  my @segs = grep {
    my ($a, $b) = ($l->[$_-1], $l->[$_]);
    (abs($a->[0]-$b->[0]) < 0.01 || abs($a->[1]-$b->[1]) < 0.01) &&
      sqrt(($b->[0]-$a->[0])**2 + ($b->[1]-$a->[1])**2) >= 110
  } 1 .. $#$l;
  return unless @segs;
  my $k = $segs[int rand @segs];
  my ($a, $b) = ($l->[$k-1], $l->[$k]);
  my $len = sqrt(($b->[0]-$a->[0])**2 + ($b->[1]-$a->[1])**2);
  my ($ux, $uy) = (($b->[0]-$a->[0])/$len, ($b->[1]-$a->[1])/$len);
  my ($wx, $wy) = (-$uy, $ux);
  my $A = 7 + int(rand(4));            # amplitude either side of the run
  my $p = 2*$TR + 5;                   # leg spacing: trace width plus a small gap
  my $cnt = 4 + int(rand(6));          # number of legs
  my $span = $cnt * $p;
  return if $span > $len - 40;
  my $s = 20 + rand($len - 40 - $span);
  my $side = rand() < 0.5 ? 1 : -1;
  my @q = ([$a->[0] + $ux*$s, $a->[1] + $uy*$s]);
  my $mv = sub { my ($du, $dw) = @_; my $c = $q[-1]; push @q, [$c->[0] + $ux*$du + $wx*$dw, $c->[1] + $uy*$du + $wy*$dw] };
  $mv->(0, $A*$side);
  for my $i (1 .. $cnt) {
    $mv->($p, 0);
    if ($i < $cnt) { $side = -$side; $mv->(0, 2*$A*$side) }
  }
  $mv->(0, -$A*$side);
  my @c = map { [@{$q[$_-1]}, @{$q[$_]}, $TR] } 1 .. $#q;
  return unless all_clear_items(\@c);
  splice @$l, $k, 0, @q;
}

sub bus_geom {
  my ($pts, $ds, $n) = @_;
  [ map { offset_line($pts, $ds, ($_ - ($n-1)/2) * $PITCH) } 0 .. $n-1 ];
}
sub all_clear {
  my $g = shift;
  my @c;
  for my $l (@$g) { push @c, [@{$l->[$_-1]}, @{$l->[$_]}, $TR] for 1..$#$l }
  all_clear_items(\@c);
}
sub all_clear_items { for (@{$_[0]}) { return 0 unless clear($_) } 1 }

my $placed = 0;
my (@bodies, @smd);

# 1. Components: chip outlines whose pad rows either launch long buses or fan out locally.
# place_chip(cx, cy, quad, pads-per-side, chance a side launches a long bus, long-bus tries)
my $cid = 0;
sub place_chip {
  my ($cx, $cy, $quad, $m, $longp, $longtries) = @_;
  my $hl = $m*6 + 6;                                       # half-length of a padded side
  my ($hx, $hy) = $quad ? ($hl, $hl) : (rand() < 0.5 ? (24, $hl) : ($hl, 24));
  # Probe a box with room for the pad rows before committing
  my ($ex, $ey) = ($hx + 30, $hy + 30);
  my @probe = ([$cx-$ex,$cy-$ey,$cx+$ex,$cy-$ey], [$cx+$ex,$cy-$ey,$cx+$ex,$cy+$ey],
               [$cx+$ex,$cy+$ey,$cx-$ex,$cy+$ey], [$cx-$ex,$cy+$ey,$cx-$ex,$cy-$ey]);
  return 0 unless all_clear_items([ (map { [@$_, $TR] } @probe), [$cx, $cy, $cx, $cy, ($ex > $ey ? $ex : $ey)] ]);
  # ...and keep chips apart so each one gets its own neighbourhood
  return 0 if grep { abs($_->[0]-$cx) < 220 && abs($_->[1]-$cy) < 220 } map { my $b = $_; map { [$b->[0]+$_->[0], $b->[1]+$_->[1]] } ([0,0],[$W,0],[-$W,0],[0,$H],[0,-$H]) } @bodies;
  $cid++;
  add_item([$_->[0], $_->[1], $_->[2], $_->[3], 1.25, $cid]) for
    ([$cx-$hx,$cy-$hy,$cx+$hx,$cy-$hy], [$cx+$hx,$cy-$hy,$cx+$hx,$cy+$hy],
     [$cx+$hx,$cy+$hy,$cx-$hx,$cy+$hy], [$cx-$hx,$cy+$hy,$cx-$hx,$cy-$hy]);
  add_item([$cx, $cy, $cx, $cy, ($hx < $hy ? $hx : $hy) - 2, $cid]);
  push @bodies, [$cx, $cy, $hx, $hy];
  my @sides = $quad ? (0, 2, 4, 6) : ($hx < $hy ? (0, 4) : (2, 6));
  $OWNER = $cid;
  for my $d (@sides) {
    my ($ux, $uy) = unit($d);
    my $h = ($d % 4 == 0) ? $hx : $hy;
    my %start = (n => $m, d0 => $d, sx => $cx + $ux*($h+10), sy => $cy + $uy*($h+10), pads => 1);
    my $ok = 0;
    if (rand() < $longp) {
      for (1 .. $longtries) { last if $ok; $ok = try_bus(%start, seg => [2, 6], orth => [80, 460], minlen => 260) }
    }
    for (1..14) { last if $ok; $ok = try_bus(%start, seg => [1, 3], orth => [12 + $m*4, 40 + $m*8], diag => [$m*6, 24 + $m*6], minlen => 20) }
    $placed += $ok;
  }
  $OWNER = 0;
  1;
}

# Focal chip: a larger chip placed first, just left of the content sheet beside the nav, with
# every side's buses routed outward so the traces all converge on it. The tile and the sheet are
# both centred on the page, so tile x = W/2 - 400 is always the sheet's left edge (50rem sheet).
place_chip($W/2 - 400 - 100, 116, 1, 8, 1, 40) or die "focal chip did not fit\n";

my $ncomp = int($W*$H / 180000) + @bodies;
for my $try (1 .. 600) {
  last if @bodies >= $ncomp;
  my $quad = rand() < 0.55;
  place_chip(4*int(rand($W/4)), 4*int(rand($H/4)), $quad, $quad ? 4 + int(rand(3)) : 3 + int(rand(4)), 0.5, 8);  # max 6 a side: the focal chip stays biggest
}

# 2. Passives: two-pad parts scattered around each chip, some with stubs out to vias
for my $b (@bodies) {
  my ($bx, $by, $bhx, $bhy) = @$b;
  my $want = 4 + int(rand(5));
  my $got = 0;
  for (1 .. 120) {
    last if $got >= $want;
    my $a = rand(6.2832);
    my $r = ($bhx > $bhy ? $bhx : $bhy) + 45 + rand(120);
    my ($x, $y) = (2*int(($bx + cos($a)*$r)/2), 2*int(($by + sin($a)*$r)/2));
    my $d = rand() < 0.5 ? 0 : 2;
    my ($ux, $uy) = unit($d);
    my @pp = ([$x - $ux*10, $y - $uy*10], [$x + $ux*10, $y + $uy*10]);
    my @c = map { [@$_, @$_, 6] } @pp;
    my (@st, @sv);
    for my $k (0, 1) {
      next if rand() < 0.3;
      my $s = $k ? 1 : -1;
      my $L = 16 + 4*int(rand(8));
      my ($qx, $qy) = ($pp[$k][0] + $s*$ux*$L, $pp[$k][1] + $s*$uy*$L);
      push @st, [@{$pp[$k]}, $qx, $qy];
      push @sv, [$qx, $qy];
    }
    push @c, [@$_, $TR] for @st;
    push @c, [@$_, @$_, $VR] for @sv;
    next unless all_clear_items(\@c);
    add_item($_) for @c;
    push @smd, map { [@$_, $d] } @pp;
    push @paths, [[$_->[0], $_->[1]], [$_->[2], $_->[3]]] for @st;
    push @pathw, (3) x @st;
    push @vias, @sv;
    $got++;
  }
}

# Via arrays: small stitching grids beside some chips
for my $b (@bodies) {
  next if rand() < 0.5;
  my ($bx, $by, $bhx, $bhy) = @$b;
  for (1 .. 30) {
    my ($cols, $rows) = (2 + int(rand(3)), 2 + int(rand(2)));
    my $a = rand(6.2832);
    my $r = ($bhx > $bhy ? $bhx : $bhy) + 50 + rand(80);
    my ($x0, $y0) = ($bx + cos($a)*$r, $by + sin($a)*$r);
    my @g = map { my $i = $_; map { [$x0 + $i*16, $y0 + $_*16] } 0 .. $rows-1 } 0 .. $cols-1;
    my @c = map { [@$_, @$_, $VR] } @g;
    # the grid's own vias sit 16 apart, so check them against the board only
    next unless all_clear_items(\@c);
    add_item($_) for @c;
    push @vias, @g;
    last;
  }
}

# 3. Long buses crossing between the clusters, at mixed spacings
for (1 .. 3000) {
  $placed += try_bus(n => pick([3,2],[4,3],[5,3],[6,2],[8,1]), pitch => pick([10,1],[12,3],[14,1]),
                     seg => [3, 9], orth => [60, 520], diag => [24, 220], minlen => 420);
}

# Power: a few fat traces, singly or in pairs
for (1 .. 400) {
  $placed += try_bus(n => pick([1,2],[2,1]), w => 5.5, pitch => 16, seg => [2, 6], orth => [100, 420],
                     diag => [30, 160], minlen => 300, pads => 0, meander => 0);
}

# 4. Wanderers: single traces that weave between everything with many turns, often meandering
for (1 .. 2500) {
  $placed += try_bus(n => 1, w => pick([2,1],[3,2]), seg => [5, 12], orth => [24, 160], diag => [16, 100],
                     minlen => 220, pads => 0, meander => 0.7);
}

# 5. Medium traces filling the gaps, some thin
for (1 .. 3000) {
  $placed += try_bus(n => pick([1,3],[2,3],[3,2]), w => pick([2,1],[3,3]), seg => [2, 6], orth => [60, 300],
                     minlen => 180, pads => 0);
}

# Loose stitching vias in leftover space
my $stitch = 0;
for (1 .. 400) {
  my ($x, $y) = (rand($W), rand($H));
  my $c = [$x, $y, $x, $y, $VR];
  next unless clear($c);
  add_item($c); push @vias, [$x, $y];
  last if ++$stitch >= 40;
}

# ---- output ----
sub f { my $v = sprintf('%.1f', shift); $v =~ s/\.0$//; $v }
# Easter egg: the outside pad of one pad row has lifted. It hinges on its front edge (where the
# trace leaves), tilts up off the board so it looks foreshortened and skewed, and swings away
# from its neighbours. Its trace now ends at the hinge instead of running under the pad.
# Kept away from the focal chip (the first body) so the joke stays a quiet find
my @liftc = grep {
  my ($dx, $dy) = (abs($_->[0] - $bodies[0][0]), abs($_->[1] - $bodies[0][1]));
  $dx = $W - $dx if $dx > $W/2; $dy = $H - $dy if $dy > $H/2;
  # Tile x within 400px of the tile centre is always under the 50rem content sheet; keep the pad
  # in the margin just beyond it, where a 1440px-wide window still shows it
  my $fromc = abs($_->[0] - $W/2);
  $_->[3] == 0 && $_->[4] >= 3 && sqrt($dx*$dx + $dy*$dy) > 400 && $fromc > 440 && $fromc < 680
} @pads;
# Prefer the first screenful (below the nav), so short pages like the 404 still show it
my @onscreen = grep { $_->[1] > 150 && $_->[1] < 650 } @liftc;
@liftc = @onscreen if @onscreen;
# ...and the one nearest the sheet, which the most window widths show
my ($lifted) = sort { abs($a->[0] - $W/2) <=> abs($b->[0] - $W/2) || $a->[1] <=> $b->[1] } @liftc;
my $liftsvg = '';
if ($lifted) {
  my ($x, $y, $d, undef, undef, $pi) = @$lifted;
  my ($ux, $uy) = unit($d);
  my ($hx, $hy) = ($x + $ux*7, $y + $uy*7);
  $paths[$pi][0] = [$hx, $hy];
  # Pad drawn in a local frame: +x along the trace, hinge at the origin, pad body behind it
  $liftsvg = sprintf('<rect x="-14" y="-4" width="14" height="8" rx="1.5" transform="translate(%s %s) rotate(%d) rotate(24) skewY(16) scale(0.55 1)"/>' . "\n",
    f($hx), f($hy), 45*$d);
  printf STDERR "lifted pad at %.0f,%.0f\n", $x, $y;
} else {
  warn "no pad in the visible margin to lift; try another seed\n";
}
my $body = '';
for my $i (0 .. $#paths) {
  my $sw = ($pathw[$i] // 3) == 3 ? '' : ' stroke-width="' . f($pathw[$i]) . '"';
  $body .= '<path d="M' . join('L', map { f($_->[0]) . ' ' . f($_->[1]) } @{$paths[$i]}) . "\"$sw/>\n";
}
my $vb = join('', map { '<circle cx="' . f($_->[0]) . '" cy="' . f($_->[1]) . "\" r=\"4.5\"/>\n" } @vias);
my $pb = $liftsvg;
for my $p (@pads) {
  next if $lifted && $p == $lifted;
  my ($x, $y, $d) = @$p;
  my ($w, $h) = ($d % 4 == 0) ? (14, 8) : (8, 14);
  $pb .= '<rect x="' . f($x - $w/2) . '" y="' . f($y - $h/2) . "\" width=\"$w\" height=\"$h\" rx=\"1.5\"/>\n";
}
# Passive pads (9 along the part, 11 across)
for (@smd) {
  my ($x, $y, $d) = @$_;
  my ($w, $h) = $d == 0 ? (9, 11) : (11, 9);
  $pb .= '<rect x="' . f($x - $w/2) . '" y="' . f($y - $h/2) . "\" width=\"$w\" height=\"$h\" rx=\"1.5\"/>\n";
}
# Chip outlines (silkscreen-style)
for (@bodies) {
  my ($x, $y, $hx, $hy) = @$_;
  $vb .= '<rect x="' . f($x - $hx) . '" y="' . f($y - $hy) . '" width="' . f(2*$hx) . '" height="' . f(2*$hy) . "\" rx=\"2\"/>\n";
}
open my $fh, '>', $out or die "$out: $!";
print $fh <<"SVG";
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="$W" height="$H" viewBox="0 0 $W $H">
<!-- Generated by _tools/pcbgen.pl (seed $seed). Shifted copies make edge-crossing traces wrap. -->
<defs><g id="t">
<g fill="none" stroke="$color" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
$body</g>
<g fill="none" stroke="$color" stroke-width="2.5">
$vb</g>
<g fill="$color">
$pb</g>
</g></defs>
SVG
for my $sx (-$W, 0, $W) { for my $sy (-$H, 0, $H) {
  print $fh "<use xlink:href=\"#t\" x=\"$sx\" y=\"$sy\"/>\n";
} }
print $fh "</svg>\n";
close $fh;
printf STDERR "%s: %d chips, %d buses, %d traces, %d vias\n", $out, scalar(@bodies), $placed, scalar(@paths), scalar(@vias);
