#/usr/bin/perl

############################################################################################################
# ec2con.pl
# Chenghao, He
# Feb 9th, 2014
# eg. perl ~/ec2con.pl --accessKey '***' --secretKey '*****' --pemKey 'demo' --securityGourpID 'sg-3ff6315a' --subnetID 'subnet-49f9bd61' --type t1.micro
############################################################################################################

use warnings;
use strict;
use Getopt::Long; 
use Net::Amazon::EC2;

 my $accessKey; 
 my $secretKey;
 my $keyName;
 my $instanceType;
 my $securityGourpID;
 my $subnetID;

 GetOptions(
    "accessKey:s" => \$accessKey,
    "secretKey:s" => \$secretKey,
    "pemKey:s" => \$keyName,
    "type:s" => \$instanceType,
    "securityGourpID:s" => \$securityGourpID,
    "subnetID:s" => \$subnetID
    );

 
 my $ec2 = Net::Amazon::EC2->new(
        AWSAccessKeyId => $accessKey, 
        SecretAccessKey => $secretKey 
 );

 # Start 1 new instance from AMI: ami-XXXXXXXX
 my $instance = $ec2->run_instances(ImageId => 'ami-69e3d500', MinCount => 1, MaxCount => 1, KeyName => $keyName, InstanceType => $instanceType, SecurityGroupId => $securityGourpID, SubnetId => $subnetID);
 
 sleep 180;
 my $running_instances = $ec2->describe_instances;
 
 my $instance_id;
 my $dns_name;
 foreach my $reservation (@$running_instances) {
    foreach my $myInstance ($reservation->instances_set) {
        if($myInstance->dns_name){
            print $myInstance->instance_id."\n";
            print $myInstance->dns_name."\n";
            $instance_id = $myInstance->instance_id;
            $dns_name = $myInstance->dns_name;
        }
    }
 }
 
 # After get instanceID, start monitor
 my $startTime = &getTime();
 print "ec2-monitor-instances $instance_id\n";
 system ("ec2-monitor-instances $instance_id");
 # Create tag according to the new created instance
 my $tag_infor = $ec2->create_tags(ResourceId =>$instance_id, Tags => {'project' => '2.1'});
 print "Instence is created successfully: $instance_id\n";
 if($tag_infor == 1){
     print "Instance: "."$instance_id\n";
     print "Dns name: "."$dns_name\n";
     print "The project tag is created successfully.\n";
 }
 else{
     print "The tag is not created successfully. The instance will be terminated.\n";
        $ec2->terminate_instances($instance_id);
 }
 
 my $sumReqPerSec = 0;
 foreach(1..10){
    my @output = readpipe("\~/benchmark/apache_bench.sh sample.jpg 100000 100 $dns_name logfile");
    foreach my $read(@output){
        chomp($read);
        $read =~ s/[\r\n]+$//;
        print $read."\n";
        if($read =~ /^Requests per second:/){
            my @words = split/:/, $read;
            $words[1] =~ s/^\s+|\s+$//;
            my @secs = split/ /, $words[1];
            $sumReqPerSec = $sumReqPerSec + $secs[0];
        }
    }
 }
 my $aveReqPerSec = $sumReqPerSec/10;
 $aveReqPerSec = sprintf("%.2f", $aveReqPerSec);
 print "Average of Requests per second: $aveReqPerSec [#/sec]\n";
 my $endTime = &getTime();

 print "CPUUtilization starts: \n";
 print "start time: $startTime\n";
 print "end time: $endTime\n";
 print "mon-get-stats CPUUtilization --dimensions \"InstanceId=$instance_id\" --start-time $startTime --end-time $endTime --period 60 --statistics \"Average\" --namespace \"AWS/EC2\" --I \'$accessKey\' --S \'$secretKey\'\n";
 my @result = readpipe("mon-get-stats CPUUtilization --dimensions \"InstanceId=$instance_id\" --start-time $startTime --end-time $endTime --period 60 --statistics \"Average\" --namespace \"AWS/EC2\" --I \'$accessKey\' --S \'$secretKey\'");
 my $resultCount = @result;
 my $sum=0;
 my $aveCPU;
 foreach my $line(@result){
    chomp($line);
    print $line."\n";
    my @lines = split /  /, $line;
    $sum = $sum + $lines[1];
 }
 $aveCPU = $sum/$resultCount;
 $aveCPU = sprintf("%.2f", $aveCPU);
 print "CPUUtilization of $instanceType is : $aveCPU Percent\n";
 print "Finish working, terminate instance: $instance_id\n";
 $ec2->terminate_instances(InstanceId => $instance_id);

sub getTime{
    (my $second, my $minute, my $hour, my $dayOfMonth, my $month, my $yearOffset, my $dayOfWeek, my $dayOfYear, my $daylightSavings) = gmtime();
    my $year = 1900 + $yearOffset;
    $month = &convert($month+1);
    $dayOfMonth = &convert($dayOfMonth);
    $hour = &convert($hour);
    $minute = &convert($minute);
    $second = &convert($second);
    my $time = "$year-$month-$dayOfMonth"."T"."$hour:$minute:$second"."\.000Z";
    return $time; 
}
 
sub convert{
    my $variable = $_[0];
    if($variable<10){
        $variable = "0".$variable;
    }
    return $variable;
}