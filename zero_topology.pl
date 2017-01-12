#!/usr/bin/perl

# script to take topology file as input and return the same topology with zeroed charges as output

use strict;
use File::Basename;

if(@ARGV+0 != 1){
  die "Usage: zero-topology.pl <topology-file>\n";
}

open(INP,"<$ARGV[0]");
open(OUT,">zeroed.top");

while(<INP>){

  chomp;
  my @a=split;

  if($a[0] eq "ATOM"){
    printf OUT "ATOM   %4s %4s %7.4f\n",$a[1],$a[2],0.0;
  }else{
    print OUT "$_\n";
  }

}
