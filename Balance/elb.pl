#/usr/bin/perl

############################################################################################################
# elb.pl
# Chenghao, He
# Feb 15th, 2014
# eg. perl ~/elb.pl --accessKey '******' --secretKey '*********' --pemKey 'Ivory' --imageID 'ami-69e3d500' --securityGroupID 'sg-3ff6315a' --elbName 'ELB' --availabilityZone 'us-east-1d' --instanceType 't1.micro'
############################################################################################################

use warnings;
use strict;
use Net::Amazon::EC2;
use VM::EC2;
use VM::EC2::ELB;
use Getopt::Long; 

my $accessKey; 
my $secretKey;
my $keyName;
my $imageID;
my $instanceType;
my $securityGroupID;
my $elbName;
my $availabilityZone;
my $instanceName;

GetOptions(
    "accessKey:s" => \$accessKey,
    "secretKey:s" => \$secretKey,
    "pemKey:s" => \$keyName,
    "imageID:s" => \$imageID,
    "instanceType:s" => \$instanceType,
    "securityGroupID:s" => \$securityGroupID,
    "elbName:s" => \$elbName,
    "availabilityZone:s" => \$availabilityZone
    );

my $lauchpad_ID;
# get Instance_ID of lauch pad
my $ec2 = Net::Amazon::EC2->new(
        AWSAccessKeyId => $accessKey, 
        SecretAccessKey => $secretKey 
    );

my $running_instances = $ec2->describe_instances;
foreach my $reservation (@$running_instances) {
    foreach my $myInstance ($reservation->instances_set) {
        if($myInstance->dns_name){
            $lauchpad_ID = $myInstance->instance_id;
        }
    }
}
print "The instance id for lauchpad is: $lauchpad_ID.\n";

# create an ELB
my $ec2ELB = VM::EC2->new(
    -access_key => $accessKey,
    -secret_key => $secretKey
);

my %listener_hash = (
    'Protocol' => 'HTTP',
    'InstancePort' => '80',
    'LoadBalancerPort' => '80');

my $lb_new = $ec2ELB->create_load_balancer(
    -load_balancer_name => $elbName,
    -listeners => \%listener_hash,
    -availability_zones => $availabilityZone
    );

sleep 120;

my $lb_run = $ec2ELB->describe_load_balancers(-load_balancer_name=>$elbName);
# asign port 8080
%listener_hash = (
    'Protocol' => 'HTTP',
    'InstancePort' => '8080',
    'LoadBalancerPort' => '8080');
$lb_run->create_load_balancer_listeners(-listeners=>\%listener_hash);
# asign healthy check
my $healthyCnt = 5;
my $intervalSecs = 60;
my $timeoutSecs = 50;
my $unhealthyCnt = 5;
my $target = 'HTTP:8080/upload';
$lb_run->configure_health_check(-healthy_threshold=>$healthyCnt,-interval=>$intervalSecs,-target=>$target,-timeout=>$timeoutSecs,-unhealthy_threshold=>$unhealthyCnt);
# asign security group
my @groups = ($securityGroupID);
$lb_run->apply_security_groups_to_load_balancer(-security_groups=>\@groups);

my $dns_name = $lb_run->DNSName;
sleep 180; 

my $requestsPerSec = 0;
my $instanceCnt = 0;
while($requestsPerSec < 2000){
    my $instance_id = &createInstance($imageID, $keyName, $instanceType, $securityGroupID, $availabilityZone,$accessKey,$secretKey);
    #register the new instance and also check the old instance, if they are not registered try to register it again
    $instanceCnt++;
    print "Now, you are trying to assign $instanceCnt instance(s) for elb: $elbName. \n";

    my $instanceRegisterCnt = &registerInstances($lauchpad_ID,$accessKey,$secretKey);
    print "Now, you have successfylly registered $instanceRegisterCnt instance(s) for elb: $elbName. \n";
    print "The instance might not register successfully this time. It also will try next time. \n";

	#instance of ELB take more time to warm up
    $requestsPerSec = &callBrenchmark($dns_name);
    print "Now, Requests Per Second is: $requestsPerSec.\n";
}
print "Now, with $instanceCnt instance(s) reach Requests Per Second: $requestsPerSec.\n";
# terminated asinged instances for ELB
&deleteInstance($accessKey,$secretKey);
print "All asigned instances for ELB has been terminated.\n";

# register Instances even try to check the one which cannot be register in the last time
sub registerInstances(){
    (my $lauchpad_ID, my $accessKey, my $secretKey) = @_;

    my $ec2ELB = VM::EC2->new(
    -access_key => $accessKey,
    -secret_key => $secretKey
    );

    my $lb_run = $ec2ELB->describe_load_balancers(-load_balancer_name=>$elbName);
    my @instancesList = $lb_run->Instances;
    my $instancesListCount = @instancesList;

    my $ec2 = Net::Amazon::EC2->new(
        AWSAccessKeyId => $accessKey, 
        SecretAccessKey => $secretKey 
    );

    my $instance_id;
    my $running_instances = $ec2->describe_instances;
    foreach my $reservation (@$running_instances) {
        foreach my $myInstance ($reservation->instances_set) {
            if($myInstance->dns_name){
                $instance_id = $myInstance->instance_id;
                if($instance_id ne $lauchpad_ID){
                    if ($instancesListCount == 0){
                        print "This instance: $instance_id is not registered to ELB and will process register...\n";
                        $lb_run->register_instances_with_load_balancer(-instances => $instance_id);
                    }
                    else{
                        my %hash;
                        foreach my $elbInstance( @instancesList){
                            $hash{$elbInstance} = $elbInstance;
                        }
                        if(!exists $hash{$instance_id}){
                            print "This instance: $instance_id is not registered to ELB and will process register...\n";
                                $lb_run->register_instances_with_load_balancer(-instances => $instance_id);
                        }
                    }
                }
            }
        }
    }
    sleep 300;

    $ec2ELB = VM::EC2->new(
    -access_key => $accessKey,
    -secret_key => $secretKey
    );
    $lb_run = $ec2ELB->describe_load_balancers(-load_balancer_name=>$elbName);
    @instancesList = $lb_run->Instances;
    $instancesListCount = @instancesList;
    return $instancesListCount;
}

# create Instance
sub createInstance(){
    (my $imageID, my $keyName, my $instanceType, my $securityGroupID, my $availabilityZone, my $accessKey, my $secretKey) = @_;

    my $ec2 = Net::Amazon::EC2->new(
        AWSAccessKeyId => $accessKey, 
        SecretAccessKey => $secretKey 
    );
    my $instance = $ec2->run_instances(ImageId => $imageID, MinCount => 1, MaxCount => 1, KeyName => $keyName, InstanceType => $instanceType, SecurityGroupId => $securityGroupID, 'Placement.AvailabilityZone' => $availabilityZone);
    my $instance_id;
    sleep 360;
    my $running_instances = $ec2->describe_instances;
    foreach my $reservation (@$running_instances) {
        foreach my $myInstance ($reservation->instances_set) {
            if($myInstance->dns_name){
                $instance_id = $myInstance->instance_id;
            }
        }
    }
    my $tag_infor = $ec2->create_tags(ResourceId =>$instance_id, Tags => {'project' => '2.3'});
    print "Instence is created successfully: $instance_id\n";
    return $instance_id;
}

# run benchmark after ELB get one more instance
sub callBrenchmark(){
    my $dns_name = $_[0];
    my $requestsPerSec;
    my @output = readpipe("\~/benchmark/apache_bench.sh sample.jpg 100000 100 $dns_name logfile");
    foreach my $read(@output){
        chomp($read);
        $read =~ s/[\r\n]+$//;
        print $read."\n";
        if($read =~ /^Requests per second:/){
            my @words = split/:/, $read;
            $words[1] =~ s/^\s+|\s+$//;
            my @secs = split/ /, $words[1];
            $requestsPerSec = $secs[0];
            chomp($requestsPerSec);
        }
    }
    return $requestsPerSec;
}

# delete Instance
sub deleteInstance(){
	(my $accessKey, my $secretKey) = @_;

	my $ec2 = Net::Amazon::EC2->new(
        AWSAccessKeyId => $accessKey, 
        SecretAccessKey => $secretKey 
    );

    my $running_instances = $ec2->describe_instances;
    foreach my $reservation (@$running_instances) {
        foreach my $myInstance ($reservation->instances_set) {
            if($myInstance->dns_name && $myInstance->instance_id ne $lauchpad_ID){
                my $instance_id = $myInstance->instance_id;
                $ec2->terminate_instances(InstanceId => $instance_id);
                print "instance: $instance_id has been terminated.\n";
            }
        }
    }
}
