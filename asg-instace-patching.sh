#!/bin/bash
#Author: Dinesh-dsm

#Patching Auto scaling instance and update launch template with new patched ami instead of launching new instance.

#app1 will make health check to EC2 & ELB with 300 seconds.
#app2 will make healtch check to EC2 with 0 seconds.

set -e
printf "\n*****************************"
printf "\nAUTOSCALING INSTANCE PATCHING"
printf "\n*****************************\n"


app1_patching(){
    echo "Reverting Health check changes"
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name $1 --health-check-type 'ELB' --health-check-grace-period 300
}


app2_patching(){
    echo "Reverting Health check changes"
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name $1 --health-check-type 'EC2' --health-check-grace-period 0
}


asg_instance_patching(){
    echo "Auto scaling Group name: $1"
    #set healthcheck to 9000 seconds
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name $1 --health-check-type 'EC2' --health-check-grace-period 9000
    #echo "Total Instance count: $instanceidcount"
    instanceidcount=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $1 --query "AutoScalingGroups[*].Instances[*].[InstanceId]" --output text | wc -l)
    ltid=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $1 --query "AutoScalingGroups[*].[LaunchTemplate.LaunchTemplateId]" --output text)
    echo "Current Lauch template ID: $ltid"
    asgtemplateverion=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $1 --query "AutoScalingGroups[*].[LaunchTemplate.Version]" --output text)
    echo "Current ASG template version: $asgtemplateverion"
    for (( i=0; i<$instanceidcount; i++ ))
    do
        instanceid=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $1 --query "AutoScalingGroups[*].Instances[$i].[InstanceId]" --output text)
        echo "Patching instance id: $instanceid"
        echo "Run command id: $(aws ssm send-command --instance-ids "$instanceid" --document-name "AWS-RunShellScript" --parameters 'commands=["echo *****yum security update*****", "yum update --security -y", "echo *****reboot*****", "init 6"]' --query "[Command.CommandId]" --output text)"
    done
    printf "\n***********************************************************************"
    printf "\nVerify Patching completed in SSM run command history or SSH to instance"
    printf "\n***********************************************************************\n"
    printf "\nMake sure server has pathces installed and up after reboot\n"
    read -p "Press enter to continue"    
}

asg_instance_postpatching(){
    read -p "Press enter to continue with AutoScaling group update with new AMI or Ctrl+C to quit"    
    asgnametag=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $1  --query "AutoScalingGroups[*].[Tags[?Key=='Name']|[0].Value]" --output text)
    instanceidcount=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $1 --query "AutoScalingGroups[*].Instances[*].[InstanceId]" --output text | wc -l)
    #echo "Total Instance count: $instanceidcount"
    ltid=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $1 --query "AutoScalingGroups[*].[LaunchTemplate.LaunchTemplateId]" --output text)
    asgtemplateverion=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $1 --query "AutoScalingGroups[*].[LaunchTemplate.Version]" --output text)
    for (( i=0; i<$instanceidcount; i++ ))
    do
        instanceid=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $1 --query "AutoScalingGroups[*].Instances[$i].[InstanceId]" --output text)
    done
    #creating new ami after patching.
    newamiid=$(aws ec2 create-image --instance-id $instanceid  --name "$asgnametag-patching-$month"  --no-reboot --query "ImageId" --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=$asgnametag-patching-$month},{Key=Tag_Name,Value=$2}]" "ResourceType=image,Tags=[{Key=Name,Value=$asgnametag-patching-$month},{Key=SO_Name,Value=$2}]" --output text)
    echo "New AMI ID: $newamiid"
    #creating new launch template with new ami
    newltversion=$(aws ec2 create-launch-template-version --launch-template-id $ltid --version-description WebVersion2 --source-version $asgtemplateverion --launch-template-data '{"ImageId":"'$newamiid'"}' --query "LaunchTemplateVersion.VersionNumber")
    echo "updated Launch Template version: $newltversion"
    #updating autoscaling group with new Launch template version
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name $1 --launch-template LaunchTemplateId=$ltid,Version=$newltversion
}

entries=( "PREPROD"
          "PROD"
          "Exit" )

PS3='Selection: '  
#default values
month=$(date +"%B_%Y_%H%M%S")



while [ "$menu" != 4 ]; do
    printf "\n----------"
    printf "\nMain Menu:"
    printf "\n----------\n\n"
    select choice in "${entries[@]}"; do
        case "$choice" in
            "PREPROD" )
                echo "*****Preprod Environment*****"
                #sub menu list
                sentries=( "App1 Patching"  #will update health to 9000 seconds in ASG and patch instance with run command
                           "App1 Post Patching" #will create new ami --> create new launch template version --> update new template version in ASG
                           "App1 On Exit Patching" #revert health check in ASG
                           "App2 Patching"
                           "App2 Post Patching"
                           "App2 On Exit Patching"
                           "Exit" )

                PS3='Selection: ' 

                while [ "$smenu" != 13 ]; do
                    printf "\n----------"
                    printf "\nSub Menu:"
                    printf "\n----------\n\n"
                    select schoice in "${sentries[@]}"; do
                        case "$schoice" in
                            "App1 Patching" )
                                asg_instance_patching "test"  #asg_name
                                break
                                ;;
                            "App1 Post Patching" )
                                asg_instance_postpatching "test" "tag_new_name"   #asg_name  tag_name_for_ami
                                break
                                ;;
                            "App1 On Exit Patching" )
                                app2_patching "test"  #asg_name
                                break
                                ;;
                            "App2 Patching" )
                                asg_instance_patching "test"
                                break
                                ;;
                            "App2 Post Patching" )
                                asg_instance_postpatching "test" "so_new_name"  
                                break
                                ;;
                            "App2 On Exit Patching" )
                                app1_patching "test"
                                break
                                ;;                                
                            "Exit" )
                                echo "Exit"
                                smenu=13
                                exit
                                ;;
                            * )
                                echo "Select the right option"
                                break
                                ;;
                        esac
                    done
                done
                #end of submenu
                break
                ;;
            "PROD" )
                echo "*****Prod Environment*****"
                sentries=( "App1 Patching"
                           "App1 Post Patching"
                           "App1 On Exit Patching"
                           "App2 Patching"
                           "App2 Post Patching"
                           "App2 On Exit Patching"
                           "Exit" )

                PS3='Selection: ' 

                while [ "$smenu" != 13 ]; do
                    printf "\n----------"
                    printf "\nSub Menu:"
                    printf "\n----------\n\n"
                    select schoice in "${sentries[@]}"; do
                        case "$schoice" in
                            "App1 Patching" )
                                asg_instance_patching "test"
                                break
                                ;;
                            "App1 Post Patching" )
                                asg_instance_postpatching "test" "so_new_name"  
                                break
                                ;;
                            "App1 On Exit Patching" )
                                app2_patching "test"
                                break
                                ;;
                            "App2 Patching" )
                                asg_instance_patching "test"
                                break
                                ;;
                            "App2 Post Patching" )
                                asg_instance_postpatching "test" "so_new_name"  
                                break
                                ;;
                            "App2 On Exit Patching" )
                                app1_patching "test"
                                break
                                ;;                                
                            "Exit" )
                                echo "Exit"
                                smenu=13
                                exit
                                ;;
                            * )
                                echo "Select the right option"
                                break
                                ;;
                        esac
                    done
                done
                #end of submenu
                break
                ;;    
            "Exit" )
                echo "Exit"
                menu=4  #number as per array
                break
                ;;   
            * )
                echo "Select the right option"
                break
                ;;
        esac
    done
done

exit 0  
