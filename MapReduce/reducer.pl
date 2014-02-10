#! /usr/bin/perl

#####################################
# reducer.pl
# Chenghao, He
# Feb 2nd, 2014
#####################################

use warnings;
use strict;

my $count;
my $date;
my $name;
my $view;
my %hashdate;
my %hashfile;

while(<>){
	chomp;
	my @list = split/\t/;
	$name = $list[0];
	my $dateview  = $list[1];
	my @l = split/,/, $dateview;
	$date = $l[0];
	$view = $l[1];
	if(exists $hashfile{$name}){
		if(exists $hashfile{$name}{$date}){
			my $tempview = $view + $hashfile{$name}{$date};
			$hashfile{$name}{$date} = $tempview;
		}
		else{
			$hashfile{$name}{$date} = $view;
		}
	}
	else{
		my %hashtemp = ($date, $view);
		$hashfile{$name} = \%hashtemp;
	}
}

foreach my $filename (keys %hashfile){
	$count = 0;
	foreach my $filedate (keys %{$hashfile{$filename}}) {
		$count = $count + $hashfile{$filename}{$filedate};
	}
	if ($count>100000) {
		print $count."\t".$filename."\t";
		foreach my $filedate (keys %{$hashfile{$filename}}) {
			print $filedate."\t".$hashfile{$filename}{$filedate}."\t";
		}
		print "\n";
	}
}

#test code：
#foreach my $filename (keys %hashfile){
#	foreach my $filedate (keys %{$hashfile{$filename}}) {
#		print $filename." ".$filedate." ".$hashfile{$filename}{$filedate}."\n";
#	}
#}

