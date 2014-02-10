#! /usr/bin/perl

#####################################
# helper.pl
# Chenghao, He
# Feb 2nd, 2014
#####################################

use warnings;
use strict;

my @entries;
my $max = 0;
my $maxFile = "";
my $lineCount = 0;
my $findLine = "";

@entries = <*>;

foreach my $file (@entries){
	#print "file: $file\n";
	open(FILE, $file) or die $!;
	while(<FILE>){
		$lineCount++;
		chomp;
		my @list = split/\t/;
		#print "list0: $list[0]\n";
		#print "list1: $list[1]\n";
		#print "filename: $file\n";
		if($max < $list[0]){
			$max = $list[0];
			$maxFile = $list[1];
		}
		if($list[1] =~ /.*James.*Gandolfini.*/){
			$findLine = $_;
		}
	}
	close FILE;
}

print "max: $max\n";
print "maxFile: $maxFile\n";
print "lineCount: $lineCount\n";
print "findLine: $findLine\n";
