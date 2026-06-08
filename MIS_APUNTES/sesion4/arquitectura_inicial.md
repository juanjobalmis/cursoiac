# Propuesta inicial de arquitectura AWS

```puml { align=center }
@startuml

' https://awslabs.github.io/aws-icons-for-plantuml/

!define AWSPuml https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/v23.0/dist

!include AWSPuml/AWSCommon.puml
!include AWSPuml/AWSSimplified.puml
!include AWSPuml/Groups/AWSCloud.puml
!include AWSPuml/Groups/VPC.puml
!include AWSPuml/Groups/AvailabilityZone.puml
!include AWSPuml/Groups/PublicSubnet.puml
!include AWSPuml/Groups/PrivateSubnet.puml
!include AWSPuml/Groups/AutoScalingGroup.puml
!include AWSPuml/NetworkingContentDelivery/VPCNATGateway.puml
!include AWSPuml/NetworkingContentDelivery/VPCInternetGateway.puml
!include AWSPuml/NetworkingContentDelivery/ElasticLoadBalancingApplicationLoadBalancer.puml
!include AWSPuml/Database/AuroraMySQLInstance.puml
!include AWSPuml/Compute/EC2Instance.puml
!include AWSPuml/Storage/EFS.puml
!include AWSPuml/ManagementGovernance/CloudFormationTemplate.puml

hide stereotype
scale 600 width
left to right direction
' skinparam linetype ortho

AWSCloudGroup(cloud) {

    VPCInternetGateway(igw, "Internet\nGateway", "")

    VPCGroup(vpc) {

        ElasticLoadBalancingApplicationLoadBalancer(alb, "Balanceador\nde carga (ALB)", "")

        AvailabilityZoneGroup(az_1b, "AZ us-east-1b") {
          PublicSubnetGroup(pub_b, "Subred pública\ren zona b") #ivory {
                VPCNATGateway(nat_gateway_b, "NAT\nGateway", "")  #transparent
            }
            PrivateSubnetGroup(priv_b, "Subred privada\r en zona b") #azure {
                AuroraMySQLInstance(rds_b, "RDS\nMySQL", "")  #transparent
                EC2Instance(ec2_b, "Instancia T3\ncon\nWordpress", "") #transparent
            }
        }          

        AvailabilityZoneGroup(az_1a, "AZ us-east-1a") {            
            PublicSubnetGroup(pub_a, "Subred pública\ren zona a") #ivory {
                VPCNATGateway(nat_gateway_a, "NAT\nGateway", "")  #transparent
            }
            PrivateSubnetGroup(priv_a, "Subred privada\ren zona a") #azure {
                    AuroraMySQLInstance(rds_a, "RDS\nMySQL", "")  #transparent
                    AutoScalingGroupGroup(asg_a, "AutoScaling") #transparent {
                        EC2Instance(ec2_a, "Instancia T3\ncon\nWordpress", "") #transparent
                    }
            }
        }
    }

    EFS(efs, "Elastic File\nSystem", "")
    CloudFormationTemplate(launchTemplate, "Launch Template\ncon user data", "")

    igw <--> alb
    igw --> nat_gateway_a
    igw --> nat_gateway_b
    alb <--> ec2_a
    alb <--> ec2_b
    nat_gateway_a --> ec2_a
    nat_gateway_b --> ec2_b
    ec2_a <--> rds_a
    ec2_b <--> rds_b

    launchTemplate --> asg_a
    efs --> ec2_a
}

@enduml
```
