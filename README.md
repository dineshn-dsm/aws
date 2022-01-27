# aws
aws related scripts

SCript Name: asg-instace-patching.sh

#Patching Auto scaling instance and update launch template with new patched ami instead of launching new instance.

#app1 will make health check to EC2 & ELB with 300 seconds.
#app2 will make healtch check to EC2 with 0 seconds.

During patching script will perform below activity.
 1. Set ASG healthcheck to EC2 and seconds to 9000 #step name : App# Patching
 2. Patch instances attached to ASG using run command(performs yum update --security and reboot ) #step name : App# Patching
 3. Once server is up , new AMI will be created and create new Launch template version with new AMI and update new version in Auto scaling group. #step name : App# Post Patching
 4. Revert Healthcheck settings back.
 
 
 Requirement:
 Auto scaling group name
 Tag details if required to attach to New ami and snapshots.
