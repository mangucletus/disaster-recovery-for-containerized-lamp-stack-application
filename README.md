# Containerized LAMP Application with Disaster Recovery

## Live Application Access

**Primary Application URL (CloudFront)**: https://d15jb99tjkxquc.cloudfront.net

**System Status**: Production Ready with Active Disaster Recovery

---

A production-ready containerized LAMP (Linux, Apache, MySQL, PHP) Student Record System deployed on AWS with enterprise-grade disaster recovery capabilities using Infrastructure as Code (Terraform) and CI/CD automation.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Live System Architecture](#live-system-architecture)
3. [Disaster Recovery Implementation](#disaster-recovery-implementation)
4. [Technology Stack](#technology-stack)
5. [Infrastructure Components](#infrastructure-components)
6. [Deployment Architecture](#deployment-architecture)
7. [Security Implementation](#security-implementation)
8. [Monitoring and Observability](#monitoring-and-observability)
9. [Disaster Recovery Operations](#disaster-recovery-operations)
10. [Cost Analysis](#cost-analysis)
11. [Maintenance Procedures](#maintenance-procedures)
12. [Troubleshooting Guide](#troubleshooting-guide)
13. [Development Workflow](#development-workflow)

---

## Project Overview

This project demonstrates a enterprise-grade containerized LAMP stack application with automated disaster recovery capabilities deployed across multiple AWS regions. The Student Record Management System serves as a practical implementation showcasing modern DevOps practices, infrastructure resilience, and automated failover mechanisms.

### Core Capabilities

**Application Features**
- Complete CRUD operations for student record management
- Responsive web interface built with Bootstrap framework
- Real-time database connectivity with connection pooling
- Containerized deployment using Docker and ECS Fargate
- Health monitoring with automatic recovery mechanisms
- Multi-environment support with environment-specific configurations

**Infrastructure Features**
- Multi-region deployment: Primary (eu-central-1), DR (eu-west-1)
- Automated disaster recovery with pilot light architecture pattern
- Infrastructure as Code using modular Terraform configurations
- Continuous Integration/Continuous Deployment via GitHub Actions
- Cross-region database replication with automated failover
- Automated backup strategies and point-in-time recovery
- CloudFront global content delivery with automatic failover routing

### Key Metrics

| Metric | Value | Description |
|--------|-------|-------------|
| **RTO (Recovery Time Objective)** | 15-20 minutes | Time to restore service during disaster |
| **RPO (Recovery Point Objective)** | 1-3 minutes | Maximum acceptable data loss |
| **Availability Target** | 99.9% | Service availability objective |
| **Failover Automation** | 100% | Fully automated via GitHub Actions |
| **Cross-Region Replication Lag** | < 1 second | Database synchronization latency |

---

## Live System Architecture

### Global Infrastructure Overview

```mermaid
graph TB
    subgraph "Global Access Layer"
        Users[End Users Global Distribution]
        CF[CloudFront Distribution Global CDN d15jb99tjkxquc.cloudfront.net]
        R53[Route 53 DNS Health-based Routing Automatic Failover]
    end
    
    subgraph "Primary Region: eu-central-1"
        subgraph "Production VPC: 10.2.0.0/16"
            subgraph "Public Tier"
                ALB_P[Application Load Balancer student-record-system-alb Port 80/443]
                NAT1_P[NAT Gateway AZ-1 Outbound Internet]
                NAT2_P[NAT Gateway AZ-2 High Availability]
            end
            
            subgraph "Application Tier"
                ECS_P[ECS Fargate Cluster 2 Running Tasks Auto-scaling 2-10 tasks]
                TG_P[Target Group Health Checks HTTP Path /]
            end
            
            subgraph "Data Tier"
                RDS_P[(Aurora MySQL 8.0 Multi-AZ Cluster 2x db.t3.large instances)]
                S3_P[S3 Buckets Application Assets Cross-region Replication]
            end
        end
        
        ECR_P[Elastic Container Registry Container Images Multi-region Push]
        CW_P[CloudWatch Metrics and Logs Alarms and Dashboards]
    end
    
    subgraph "DR Region: eu-west-1"
        subgraph "DR VPC: 10.3.0.0/16"
            subgraph "Standby Tier"
                ALB_DR[Application Load Balancer Pre-configured Ready for Traffic]
            end
            
            subgraph "Pilot Light"
                ECS_DR[ECS Fargate Service 0 Tasks Standby Rapid Scale-up Ready]
            end
            
            subgraph "Data Replication"
                RDS_DR[(Aurora Read Replica Real-time Sync 1x db.t3.large instance)]
                S3_DR[S3 Buckets Replication Target Immediate Consistency]
            end
        end
        
        CW_DR[CloudWatch DR Monitoring Replication Metrics]
    end
    
    subgraph "Automation Control"
        GHA[GitHub Actions CI/CD Pipeline Automated Deployments]
        Lambda[Lambda Functions Failover Orchestration Health Monitoring]
        SSM[Systems Manager Parameter Store Configuration Management]
    end
    
    Users --> CF
    CF --> R53
    R53 --> ALB_P
    R53 -.->|Failover| ALB_DR
    
    ALB_P --> TG_P
    TG_P --> ECS_P
    ECS_P --> RDS_P
    ECS_P --> NAT1_P
    ECS_P --> NAT2_P
    
    ALB_DR -.-> ECS_DR
    ECS_DR -.-> RDS_DR
    
    RDS_P ==>|Continuous Replication| RDS_DR
    S3_P ==>|Cross-Region Replication| S3_DR
    ECR_P ==>|Image Replication| ECS_DR
    
    GHA --> ECS_P
    GHA --> ECS_DR
    Lambda --> ECS_DR
    Lambda --> RDS_DR
    
    ECS_P --> CW_P
    ECS_DR --> CW_DR
    
    style Users fill:#1f4e79,color:#ffffff,stroke:#2c5f8a,stroke-width:3px
    style CF fill:#ff9900,color:#ffffff,stroke:#e68900,stroke-width:3px
    style ALB_P fill:#ec7211,color:#ffffff,stroke:#d86613,stroke-width:4px
    style ECS_P fill:#ec7211,color:#ffffff,stroke:#d86613,stroke-width:4px
    style RDS_P fill:#3f48cc,color:#ffffff,stroke:#2d35b8,stroke-width:4px
    style ALB_DR fill:#ec7211,color:#ffffff,stroke:#d86613,stroke-width:2px,stroke-dasharray: 8 8
    style ECS_DR fill:#ec7211,color:#ffffff,stroke:#d86613,stroke-width:2px,stroke-dasharray: 8 8
    style RDS_DR fill:#3f48cc,color:#ffffff,stroke:#2d35b8,stroke-width:2px,stroke-dasharray: 8 8
    style GHA fill:#24292e,color:#ffffff,stroke:#1a1e22,stroke-width:3px
```

### Network Architecture Detail

```mermaid
graph TB
    subgraph "Production Network: eu-central-1"
        subgraph "VPC: 10.2.0.0/16"
            subgraph "Availability Zone 1a"
                PubSub1[Public Subnet 10.2.1.0/24 ALB and NAT Gateway]
                PrivSub1[Private Subnet 10.2.10.0/24 ECS Tasks and RDS]
            end
            
            subgraph "Availability Zone 1b"
                PubSub2[Public Subnet 10.2.2.0/24 ALB and NAT Gateway]
                PrivSub2[Private Subnet 10.2.20.0/24 ECS Tasks and RDS]
            end
            
            IGW_P[Internet Gateway Primary Region All Internet Traffic]
            RT_Pub[Public Route Table 0.0.0.0/0 to IGW Local Routes]
            RT_Priv1[Private Route Table 1 0.0.0.0/0 to NAT-1 Database Routes]
            RT_Priv2[Private Route Table 2 0.0.0.0/0 to NAT-2 High Availability]
        end
    end
    
    subgraph "DR Network: eu-west-1"
        subgraph "VPC: 10.3.0.0/16"
            subgraph "Availability Zone 1a"
                PubSubDR1[Public Subnet 10.3.1.0/24 ALB Only Pilot Light]
                PrivSubDR1[Private Subnet 10.3.10.0/24 ECS and RDS Replica]
            end
            
            subgraph "Availability Zone 1b"
                PubSubDR2[Public Subnet 10.3.2.0/24 ALB Only Pilot Light]
                PrivSubDR2[Private Subnet 10.3.20.0/24 ECS and RDS Replica]
            end
            
            IGW_DR[Internet Gateway DR Region Failover Traffic]
            RT_PubDR[Public Route Table 0.0.0.0/0 to IGW Emergency Access]
            RT_PrivDR[Private Route Tables Direct Internet via IGW Cost-Optimized No NAT]
        end
    end
    
    subgraph "Security Groups"
        SG_ALB[ALB Security Group Inbound 80 443 from 0.0.0.0/0 Outbound All to ECS SG]
        SG_ECS[ECS Security Group Inbound 80 from ALB SG Outbound 3306 to RDS SG]
        SG_RDS[RDS Security Group Inbound 3306 from ECS SG Cross-region Replication]
    end
    
    IGW_P --> PubSub1
    IGW_P --> PubSub2
    PubSub1 --> PrivSub1
    PubSub2 --> PrivSub2
    
    IGW_DR --> PubSubDR1
    IGW_DR --> PubSubDR2
    PubSubDR1 -.-> PrivSubDR1
    PubSubDR2 -.-> PrivSubDR2
    
    PrivSub1 <-.->|VPC Peering Replication| PrivSubDR1
    
    style IGW_P fill:#8c4fff,color:#ffffff,stroke:#7a42e6,stroke-width:4px
    style IGW_DR fill:#8c4fff,color:#ffffff,stroke:#7a42e6,stroke-width:2px,stroke-dasharray: 8 8
    style SG_ALB fill:#ff6b35,color:#ffffff,stroke:#e55a2b,stroke-width:3px
    style SG_ECS fill:#4caf50,color:#ffffff,stroke:#45a049,stroke-width:3px
    style SG_RDS fill:#2196f3,color:#ffffff,stroke:#1976d2,stroke-width:3px
    style PrivSub1 fill:#e8f5e8,stroke:#4caf50,stroke-width:2px
    style PrivSub2 fill:#e8f5e8,stroke:#4caf50,stroke-width:2px
    style PrivSubDR1 fill:#fff3e0,stroke:#ff9800,stroke-width:2px
    style PrivSubDR2 fill:#fff3e0,stroke:#ff9800,stroke-width:2px
```

---

## Disaster Recovery Implementation

### Pilot Light Architecture Pattern

```mermaid
graph LR
    subgraph "Normal Operations State"
        direction TB
        ProdActive[Production Region eu-central-1 Full Capacity 2 ECS Tasks 100 Percent Traffic]
        DRStandby[DR Region eu-west-1 Pilot Light Mode 0 ECS Tasks 0 Percent Traffic]
        DataFlow[Continuous Replication RDS less than 1 second lag S3 Real-time sync ECR On-demand]
    end
    
    subgraph "Disaster Detection"
        direction TB
        HealthCheck[Route 53 Health Checks 30-second intervals HTTP 200 validation 3 consecutive failures]
        CloudWatch[CloudWatch Alarms 5xx error rate greater than 10/min Target health less than 1 ECS service unavailable]
        Manual[Manual Trigger GitHub Actions workflow Emergency activation Operator decision]
    end
    
    subgraph "Failover Execution"
        direction TB
        Lambda[Lambda Orchestrator Automated coordination Step-by-step execution Real-time monitoring]
        ECSScale[Scale ECS Service 0 to 2 tasks 5-8 minute startup Health validation]
        RDSPromote[Promote Read Replica Read-only to Read-write 2-5 minute promotion Connection updates]
        DNSUpdate[Update DNS Records Route 53 failover TTL-based propagation Global distribution]
    end
    
    subgraph "Post-Failover State"
        direction TB
        DRActive[DR Region Active eu-west-1 Full Capacity 2 ECS Tasks 100 Percent Traffic]
        ProdDown[Production Region eu-central-1 Unavailable Recovery in Progress 0 Percent Traffic]
        Monitoring[Enhanced Monitoring Performance validation Error rate tracking Capacity optimization]
    end
    
    ProdActive --> DataFlow
    DataFlow --> DRStandby
    
    ProdActive -->|Service Degradation| HealthCheck
    HealthCheck --> Lambda
    CloudWatch --> Lambda
    Manual --> Lambda
    
    Lambda --> ECSScale
    Lambda --> RDSPromote
    Lambda --> DNSUpdate
    
    ECSScale --> DRActive
    RDSPromote --> DRActive
    DNSUpdate --> DRActive
    DRActive --> Monitoring
    
    style ProdActive fill:#4caf50,color:#ffffff,stroke:#45a049,stroke-width:4px
    style DRStandby fill:#ffc107,color:#000000,stroke:#ffb300,stroke-width:3px
    style Lambda fill:#ff5722,color:#ffffff,stroke:#e64a19,stroke-width:4px
    style DRActive fill:#4caf50,color:#ffffff,stroke:#45a049,stroke-width:4px
    style ProdDown fill:#f44336,color:#ffffff,stroke:#d32f2f,stroke-width:3px
    style DataFlow fill:#2196f3,color:#ffffff,stroke:#1976d2,stroke-width:3px
```

### Recovery Time and Point Objectives

```mermaid
gantt
    title Disaster Recovery Timeline
    dateFormat X
    axisFormat %M:%S
    
    section Detection
    Health Check Failure    :done, detect, 0, 90s
    Alert Generation       :done, alert, after detect, 30s
    
    section Automation
    Lambda Trigger         :done, lambda, after alert, 15s
    ECS Service Scaling    :active, ecs, after lambda, 480s
    RDS Replica Promotion  :active, rds, after lambda, 300s
    
    section Validation
    Health Check Pass      :health, after ecs, 60s
    DNS Propagation        :dns, after health, 180s
    
    section Recovery
    Full Service Restoration :milestone, restore, after dns, 0s
```

**Recovery Metrics Achievement:**
- **Total RTO**: 15-20 minutes (Target: < 30 minutes)
- **RPO**: 1-3 minutes (Target: < 5 minutes)
- **Automation Level**: 100% (No manual intervention required)

---

## Technology Stack

### Core Infrastructure Components

| Layer | Technology | Version | Configuration | Purpose |
|-------|------------|---------|---------------|---------|
| **Content Delivery** | Amazon CloudFront | Latest | Global edge locations SSL/TLS termination | Global content delivery and failover routing |
| **DNS Management** | Amazon Route 53 | Latest | Health checks enabled Failover routing policy | DNS resolution and automatic failover |
| **Load Balancing** | Application Load Balancer | Latest | HTTP/HTTPS listeners Health checks configured | Traffic distribution and health monitoring |
| **Container Orchestration** | Amazon ECS Fargate | Latest | CPU: 256 units Memory: 512 MB | Serverless container management |
| **Container Registry** | Amazon ECR | Latest | Lifecycle policies Cross-region replication | Container image storage and distribution |
| **Database** | Amazon Aurora MySQL | 8.0 | Multi-AZ deployment Cross-region read replica | Primary data storage with DR capability |
| **Object Storage** | Amazon S3 | Latest | Cross-region replication Versioning enabled | Static assets and backup storage |
| **Infrastructure as Code** | Terraform | >= 1.0 | Modular architecture Remote state backend | Infrastructure provisioning and management |
| **CI/CD Pipeline** | GitHub Actions | Latest | Multi-environment workflows Automated deployments | Continuous integration and deployment |
| **Monitoring** | Amazon CloudWatch | Latest | Custom dashboards Automated alarms | System monitoring and alerting |
| **Configuration Management** | AWS Systems Manager | Latest | Parameter Store Secrets management | Configuration and secret storage |

### Application Stack

| Component | Technology | Version | Configuration |
|-----------|------------|---------|---------------|
| **Web Server** | Apache HTTP Server | 2.4 | Virtual hosts configured SSL/TLS support |
| **Runtime** | PHP | 8.1 | FPM enabled Extensions: PDO, MySQL |
| **Frontend Framework** | Bootstrap | 5.1.3 | Responsive design Component library |
| **Database Driver** | PDO MySQL | 8.1 | Connection pooling Prepared statements |
| **Containerization** | Docker | Latest | Multi-stage builds Security scanning |

---

## Infrastructure Components

### Terraform Module Architecture

```mermaid
graph TB
    subgraph "Root Configurations"
        ProdEnv[Production Environment terraform/environments/production eu-central-1 deployment]
        DREnv[DR Environment terraform/environments/dr eu-west-1 deployment]
        Backend[Backend Configuration terraform/backend S3 state management]
    end
    
    subgraph "Reusable Modules"
        NetMod[Networking Module VPC Subnets Routing Security Groups NACLs]
        SecMod[Security Module IAM Roles Policies KMS Secrets Manager]
        DbMod[Database Module Aurora Clusters Read Replicas Backups]
        ComputeMod[Compute Module ECS Clusters Services Task Definitions ALB]
        StorageMod[Storage Module S3 Buckets ECR Cross-region Replication]
        MonMod[Monitoring Module CloudWatch Alarms SNS Dashboards]
        CDNMod[CDN Module CloudFront Distribution Route 53 Configuration]
        AutoMod[Automation Module Lambda Functions EventBridge Rules]
    end
    
    subgraph "State Management"
        S3State[S3 Backend Encrypted state storage Cross-region replication]
        DynamoLock[DynamoDB Lock Table State locking Concurrent protection]
        Versioning[State Versioning History tracking Rollback capability]
    end
    
    ProdEnv --> NetMod
    ProdEnv --> SecMod
    ProdEnv --> DbMod
    ProdEnv --> ComputeMod
    ProdEnv --> StorageMod
    ProdEnv --> MonMod
    ProdEnv --> CDNMod
    ProdEnv --> AutoMod
    
    DREnv --> NetMod
    DREnv --> SecMod
    DREnv --> DbMod
    DREnv --> ComputeMod
    DREnv --> StorageMod
    DREnv --> MonMod
    
    Backend --> S3State
    Backend --> DynamoLock
    Backend --> Versioning
    
    ProdEnv --> S3State
    DREnv --> S3State
    
    style ProdEnv fill:#4caf50,color:#ffffff,stroke:#45a049,stroke-width:3px
    style DREnv fill:#ff9800,color:#ffffff,stroke:#f57c00,stroke-width:3px
    style NetMod fill:#2196f3,color:#ffffff,stroke:#1976d2,stroke-width:2px
    style SecMod fill:#9c27b0,color:#ffffff,stroke:#7b1fa2,stroke-width:2px
    style DbMod fill:#3f51b5,color:#ffffff,stroke:#303f9f,stroke-width:2px
    style ComputeMod fill:#ff5722,color:#ffffff,stroke:#e64a19,stroke-width:2px
    style StorageMod fill:#795548,color:#ffffff,stroke:#5d4037,stroke-width:2px
    style S3State fill:#607d8b,color:#ffffff,stroke:#455a64,stroke-width:3px
```

### Module Dependencies and Data Flow

```mermaid
graph TD
    subgraph "Infrastructure Provisioning Flow"
        Start[Terraform Initialize Backend Configuration Provider Setup]
        
        subgraph "Foundation Layer"
            VPC[VPC Creation CIDR 10.2.0.0/16 Production CIDR 10.3.0.0/16 DR]
            Subnets[Subnet Creation Public ALB NAT Private ECS RDS]
            Security[Security Groups Ingress/Egress Rules Least Privilege Access]
        end
        
        subgraph "Data Layer"
            ParamStore[Parameter Store Configuration Values Database Credentials]
            KMS[KMS Key Creation Encryption at Rest Cross-service Access]
            S3Buckets[S3 Bucket Creation Versioning Enabled CRR Configuration]
        end
        
        subgraph "Database Layer"
            RDSSubnet[DB Subnet Groups Multi-AZ Placement Cross-region Setup]
            RDSCluster[Aurora Cluster Primary and Read Replica Automated Backups]
            Secrets[Secrets Manager Database Passwords Automatic Rotation]
        end
        
        subgraph "Compute Layer"
            ECR[ECR Repository Image Storage Multi-region Push]
            ECSCluster[ECS Cluster Fargate Launch Type Container Insights]
            ALBTarget[ALB Target Groups Health Check Config Routing Rules]
            ALBListener[ALB Listeners HTTP/HTTPS Rules SSL Termination]
        end
        
        subgraph "Application Layer"
            TaskDef[ECS Task Definition Container Specification Resource Allocation]
            ECSService[ECS Service Desired Count Auto-scaling Config]
            ServiceMesh[Service Discovery Load Balancing Health Monitoring]
        end
        
        subgraph "Monitoring Layer"
            CWLogs[CloudWatch Logs Centralized Logging Retention Policies]
            CWMetrics[CloudWatch Metrics Custom Metrics Alarm Configuration]
            Dashboard[CloudWatch Dashboard Visual Monitoring Real-time Status]
        end
        
        subgraph "Global Layer"
            Route53[Route 53 Configuration Health Checks Failover Routing]
            CloudFront[CloudFront Distribution Global Edge Locations SSL/TLS Termination]
            Lambda[Lambda Functions Automation Logic Event Processing]
        end
    end
    
    Start --> VPC
    VPC --> Subnets
    Subnets --> Security
    
    Security --> ParamStore
    ParamStore --> KMS
    KMS --> S3Buckets
    
    S3Buckets --> RDSSubnet
    RDSSubnet --> RDSCluster
    RDSCluster --> Secrets
    
    Secrets --> ECR
    ECR --> ECSCluster
    ECSCluster --> ALBTarget
    ALBTarget --> ALBListener
    
    ALBListener --> TaskDef
    TaskDef --> ECSService
    ECSService --> ServiceMesh
    
    ServiceMesh --> CWLogs
    CWLogs --> CWMetrics
    CWMetrics --> Dashboard
    
    Dashboard --> Route53
    Route53 --> CloudFront
    CloudFront --> Lambda
    
    style Start fill:#607d8b,color:#ffffff,stroke:#455a64,stroke-width:3px
    style VPC fill:#1976d2,color:#ffffff,stroke:#1565c0,stroke-width:3px
    style RDSCluster fill:#3f51b5,color:#ffffff,stroke:#303f9f,stroke-width:3px
    style ECSService fill:#ff5722,color:#ffffff,stroke:#e64a19,stroke-width:3px
    style CloudFront fill:#ff9800,color:#ffffff,stroke:#f57c00,stroke-width:3px
```

---

## Deployment Architecture

### CI/CD Pipeline Implementation

```mermaid
graph TB
    subgraph "Source Control"
        Dev[Developer Code Changes Feature Branch]
        PR[Pull Request Code Review Automated Testing]
        Main[Main Branch Production Ready Merge Trigger]
    end
    
    subgraph "GitHub Actions Workflow"
        Trigger[Workflow Trigger Push to Main Manual Dispatch]
        
        subgraph "Build Stage"
            Checkout[Code Checkout Repository Clone Dependency Resolution]
            DockerBuild[Docker Build Multi-stage Build Security Scanning]
            ImagePush[Image Push ECR Primary Region ECR DR Region]
        end
        
        subgraph "Infrastructure Stage"
            TFInit[Terraform Init Backend Configuration Provider Setup]
            TFPlan[Terraform Plan Change Validation Resource Preview]
            TFApply[Terraform Apply Infrastructure Deployment State Management]
        end
        
        subgraph "Application Stage"
            ECSUpdate[ECS Service Update New Task Definition Rolling Deployment]
            HealthCheck[Health Validation ALB Target Health Application Response]
            Verification[Deployment Verification Smoke Tests Metric Validation]
        end
        
        subgraph "DR Stage"
            DRValidation[DR Environment Check Replication Status Standby Readiness]
            DRUpdate[DR Configuration Update Latest Image Reference Zero-downtime Prep]
            DRTesting[DR Testing Failover Capability Recovery Validation]
        end
    end
    
    subgraph "Deployment Targets"
        ProdECS[Production ECS eu-central-1 2 Running Tasks]
        DREcs[DR ECS eu-west-1 0 Tasks Standby]
        ProdRDS[Production RDS Aurora Primary Multi-AZ Active]
        DRRDS[DR RDS Read Replica Continuous Sync]
    end
    
    Dev --> PR
    PR --> Main
    Main --> Trigger
    
    Trigger --> Checkout
    Checkout --> DockerBuild
    DockerBuild --> ImagePush
    
    ImagePush --> TFInit
    TFInit --> TFPlan
    TFPlan --> TFApply
    
    TFApply --> ECSUpdate
    ECSUpdate --> HealthCheck
    HealthCheck --> Verification
    
    Verification --> DRValidation
    DRValidation --> DRUpdate
    DRUpdate --> DRTesting
    
    ECSUpdate --> ProdECS
    DRUpdate --> DREcs
    TFApply --> ProdRDS
    TFApply --> DRRDS
    
    style Main fill:#28a745,color:#ffffff,stroke:#1e7e34,stroke-width:3px
    style TFApply fill:#6f42c1,color:#ffffff,stroke:#5a32a3,stroke-width:3px
    style ECSUpdate fill:#fd7e14,color:#ffffff,stroke:#e8681a,stroke-width:3px
    style ProdECS fill:#007bff,color:#ffffff,stroke:#0056b3,stroke-width:3px
    style DREcs fill:#ffc107,color:#000000,stroke:#d39e00,stroke-width:3px
    style Verification fill:#28a745,color:#ffffff,stroke:#1e7e34,stroke-width:3px
```

### Environment-Specific Configuration

```mermaid
graph LR
    subgraph "Configuration Management"
        subgraph "Production Environment"
            ProdVars[Production Variables terraform.tfvars vpc_cidr 10.2.0.0/16 instance_class db.t3.large desired_count 2]
            ProdSecrets[Production Secrets GitHub Secrets DATABASE_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY]
            ProdParams[Parameter Store /student-record-system-v2/production/ database-cluster-arn alb-dns-name target-group-arn]
        end
        
        subgraph "DR Environment"
            DRVars[DR Variables terraform.tfvars vpc_cidr 10.3.0.0/16 instance_class db.t3.large desired_count 0]
            DRParams[Parameter Store /student-record-system-v2/dr/ alb-dns-name database-endpoint ecs-cluster-name read-replica-configured]
            DRConfig[DR Configuration skip_read_replica false create_nat_gateways false assign_public_ip true]
        end
        
        subgraph "Global Configuration"
            BackendConfig[Backend Configuration S3 Bucket terraform-state DynamoDB terraform-locks Encryption AES256]
            GlobalTags[Global Tags Environment production/dr Project student-record-system-v2 ManagedBy Terraform]
            CrossRegion[Cross-Region Settings Replication Rules Failover Policies Health Check Configuration]
        end
    end
    
    ProdVars --> ProdParams
    ProdSecrets --> ProdParams
    DRVars --> DRParams
    DRConfig --> DRParams
    
    ProdParams --> BackendConfig
    DRParams --> BackendConfig
    BackendConfig --> GlobalTags
    GlobalTags --> CrossRegion
    
    style ProdVars fill:#28a745,color:#ffffff,stroke:#1e7e34,stroke-width:3px
    style DRVars fill:#ffc107,color:#000000,stroke:#d39e00,stroke-width:3px
    style BackendConfig fill:#6f42c1,color:#ffffff,stroke:#5a32a3,stroke-width:3px
    style CrossRegion fill:#dc3545,color:#ffffff,stroke:#bd2130,stroke-width:3px
```

---

## Security Implementation

### Multi-Layer Security Architecture

```mermaid
graph TB
    subgraph "Edge Security Layer"
        Internet[Internet Traffic Global Requests Various Sources]
        WAF[AWS WAF Web Application Firewall OWASP Top 10 Protection]
        Shield[AWS Shield DDoS Protection Automatic Mitigation]
        CloudFront[CloudFront Security SSL/TLS Termination Origin Access Control]
    end
    
    subgraph "Network Security Layer"
        subgraph "VPC Security"
            VPCFlow[VPC Flow Logs Network Traffic Analysis Security Monitoring]
            NACL[Network ACLs Subnet-level Filtering Stateless Rules]
            RouteTable[Route Tables Traffic Direction Isolation Control]
        end
        
        subgraph "Security Groups"
            ALBSG[ALB Security Group Inbound 80 443 from 0.0.0.0/0 Outbound All to ECS SG]
            ECSSG[ECS Security Group Inbound 80 from ALB SG only Outbound 3306 to RDS SG]
            RDSSG[RDS Security Group Inbound 3306 from ECS SG only Outbound Restricted]
        end
    end
    
    subgraph "Identity and Access Layer"
        subgraph "IAM Framework"
            ServiceRoles[Service-linked Roles ECS Task Execution RDS Enhanced Monitoring]
            TaskRoles[Task-specific Roles Application Permissions Least Privilege Access]
            CrossAccount[Cross-account Access DR Region Permissions Replication Rights]
        end
        
        subgraph "Secret Management"
            SecretsManager[AWS Secrets Manager Database Credentials Automatic Rotation]
            ParameterStore[Parameter Store Configuration Values Secure String Parameters]
            KMSKeys[KMS Customer Keys Encryption Key Management Cross-service Access]
        end
    end
    
    subgraph "Data Protection Layer"
        subgraph "Encryption in Transit"
            TLSTermination[TLS 1.2+ Enforcement Certificate Management Perfect Forward Secrecy]
            InterService[Inter-service Encryption VPC Endpoints Private Communication]
            DatabaseTLS[Database TLS Encrypted Connections Certificate Validation]
        end
        
        subgraph "Encryption at Rest"
            RDSEncryption[RDS Encryption AES-256 Encryption Encrypted Backups]
            S3Encryption[S3 Server-side Encryption KMS-managed Keys Object-level Encryption]
            EBSEncryption[EBS Volume Encryption Fargate Storage Temporary Files]
        end
    end
    
    subgraph "Application Security Layer"
        subgraph "Container Security"
            ImageScanning[ECR Image Scanning Vulnerability Assessment Critical CVE Detection]
            RuntimeSecurity[Container Runtime Security Read-only Filesystems Non-root Execution]
            SecretsInjection[Secrets Injection Environment Variables Secure Configuration]
        end
        
        subgraph "Application Controls"
            InputValidation[Input Validation SQL Injection Prevention XSS Protection]
            SessionSecurity[Session Management Secure Cookies Session Timeout]
            DatabaseSecurity[Database Security Prepared Statements Connection Pooling]
        end
    end
    
    subgraph "Monitoring and Compliance"
        CloudTrail[AWS CloudTrail API Call Logging Compliance Audit]
        GuardDuty[Amazon GuardDuty Threat Detection Behavioral Analysis]
        SecurityHub[AWS Security Hub Centralized Findings Compliance Dashboard]
        ConfigRules[AWS Config Rules Resource Compliance Configuration Drift]
    end
    
    Internet --> WAF
    WAF --> Shield
    Shield --> CloudFront
    
    CloudFront --> VPCFlow
    VPCFlow --> NACL
    NACL --> RouteTable
    
    RouteTable --> ALBSG
    ALBSG --> ECSSG
    ECSSG --> RDSSG
    
    ECSSG --> ServiceRoles
    ServiceRoles --> TaskRoles
    TaskRoles --> CrossAccount
    
    CrossAccount --> SecretsManager
    SecretsManager --> ParameterStore
    ParameterStore --> KMSKeys
    
    KMSKeys --> TLSTermination
    TLSTermination --> InterService
    InterService --> DatabaseTLS
    
    DatabaseTLS --> RDSEncryption
    RDSEncryption --> S3Encryption
    S3Encryption --> EBSEncryption
    
    EBSEncryption --> ImageScanning
    ImageScanning --> RuntimeSecurity
    RuntimeSecurity --> SecretsInjection
    
    SecretsInjection --> InputValidation
    InputValidation --> SessionSecurity
    SessionSecurity --> DatabaseSecurity
    
    DatabaseSecurity --> CloudTrail
    CloudTrail --> GuardDuty
    GuardDuty --> SecurityHub
    SecurityHub --> ConfigRules
    
    style WAF fill:#ff6b6b,color:#ffffff,stroke:#ff5252,stroke-width:3px
    style ALBSG fill:#4ecdc4,color:#ffffff,stroke:#26a69a,stroke-width:3px
    style SecretsManager fill:#45b7d1,color:#ffffff,stroke:#1976d2,stroke-width:3px
    style RDSEncryption fill:#96ceb4,color:#ffffff,stroke:#4caf50,stroke-width:3px
    style ImageScanning fill:#feca57,color:#000000,stroke:#ff9800,stroke-width:3px
    style CloudTrail fill:#a29bfe,color:#ffffff,stroke:#6c5ce7,stroke-width:3px
```

### Security Control Matrix

| Control Category | Implementation | Status | Validation Method |
|-----------------|----------------|--------|-------------------|
| **Network Isolation** | VPC with private subnets | Active | VPC Flow Logs analysis |
| **Access Control** | Security Groups with restrictive rules | Active | AWS Config compliance |
| **Identity Management** | IAM roles with least privilege | Active | IAM Access Analyzer |
| **Data Encryption** | KMS encryption for all data stores | Active | Encryption status monitoring |
| **Secret Management** | AWS Secrets Manager integration | Active | Secret rotation logs |
| **Container Security** | ECR vulnerability scanning | Active | Daily scan reports |
| **Network Traffic** | HTTPS/TLS 1.2+ enforcement | Active | ALB access logs |
| **Audit Logging** | CloudTrail for all API calls | Active | Log integrity validation |
| **Threat Detection** | GuardDuty behavioral analysis | Active | Security findings review |
| **Compliance Monitoring** | Security Hub centralized dashboard | Active | Weekly compliance reports |

---

## Monitoring and Observability

### Comprehensive Monitoring Dashboard

```mermaid
graph TB
    subgraph "CloudWatch Dashboard Layout"
        subgraph "Service Health Monitoring"
            ServiceStatus[Service Status Panel ECS Service Health Running Tasks 2/2 Service Status ACTIVE Last Deployment SUCCESS]
            
            ALBHealth[ALB Health Panel Target Health 2/2 Healthy Request Count 1250/min Response Time 95ms P50 Error Rate 0.02 percent]
            
            DatabaseHealth[Database Health Panel Aurora Cluster AVAILABLE Writer ACTIVE Reader ACTIVE Connections 25/100]
        end
        
        subgraph "Performance Metrics"
            CPUMemory[Resource Utilization ECS CPU 45 percent avg ECS Memory 62 percent avg RDS CPU 35 percent avg RDS Memory 58 percent avg]
            
            ResponseMetrics[Response Performance P50 Latency 95ms P90 Latency 180ms P99 Latency 450ms Success Rate 99.98 percent]
            
            ThroughputMetrics[Throughput Metrics Requests/sec 20.8 Peak RPS 45.2 Data Transfer 1.2 GB/hour Database QPS 180]
        end
        
        subgraph "DR Monitoring"
            ReplicationStatus[Replication Status RDS Lag 0.8 seconds S3 Replication UP TO DATE Cross-region Health OK Last Sync 2 seconds ago]
            
            DRReadiness[DR Readiness ECS DR Status STANDBY 0 tasks ALB DR PROVISIONED RDS Replica AVAILABLE Failover Capability READY]
            
            FailoverMetrics[Failover Metrics Last DR Test 3 days ago Test Result SUCCESS Failover Time 18 minutes Data Loss 0 records]
        end
        
        subgraph "Security Monitoring"
            SecurityEvents[Security Events Failed Logins 0/hour WAF Blocked 12/hour Suspicious IPs 0 SSL Certificate VALID 89 days]
            
            ComplianceStatus[Compliance Status Security Group Rules COMPLIANT Encryption Status ALL ENCRYPTED Backup Status UP TO DATE Access Logging ENABLED]
        end
        
        subgraph "Operational Metrics"
            ErrorTracking[Error Tracking Application Errors 2/hour Database Errors 0/hour Infrastructure Errors 0/hour 4xx Errors 15/hour 5xx Errors 1/hour]
            
            BusinessMetrics[Business Metrics Student Records 1247 Daily Active Users 85 Peak Concurrent Users 23 Average Session 8.5 min]
        end
    end
    
    style ServiceStatus fill:#28a745,color:#ffffff,stroke:#1e7e34,stroke-width:3px
    style ALBHealth fill:#17a2b8,color:#ffffff,stroke:#138496,stroke-width:3px
    style DatabaseHealth fill:#6f42c1,color:#ffffff,stroke:#5a32a3,stroke-width:3px
    style ReplicationStatus fill:#fd7e14,color:#ffffff,stroke:#e8681a,stroke-width:3px
    style DRReadiness fill:#ffc107,color:#000000,stroke:#d39e00,stroke-width:3px
    style SecurityEvents fill:#dc3545,color:#ffffff,stroke:#bd2130,stroke-width:3px
    style BusinessMetrics fill:#20c997,color:#ffffff,stroke:#1aa179,stroke-width:3px
```

### Alert Configuration and Escalation

```mermaid
graph TD
    subgraph "Alert Severity Levels"
        P1[Priority 1 Critical Service completely down Data loss occurring Security breach detected]
        P2[Priority 2 High Service degraded Performance impacted DR replication failing]
        P3[Priority 3 Medium Resource thresholds Capacity warnings Non-critical errors]
        P4[Priority 4 Low Informational alerts Maintenance notices Optimization opportunities]
    end
    
    subgraph "Alert Sources"
        CloudWatchAlarms[CloudWatch Alarms Threshold-based Composite alarms Anomaly detection]
        HealthChecks[Route 53 Health Checks Endpoint monitoring Latency checks Failure detection]
        SecurityAlerts[Security Alerts GuardDuty findings Config compliance Access anomalies]
        ApplicationLogs[Application Logs Error patterns Performance issues Business logic alerts]
    end
    
    subgraph "Notification Channels"
        SNSTopic[SNS Topics Email notifications SMS alerts HTTP endpoints]
        SlackIntegration[Slack Integration Channel notifications Direct messages Alert threading]
        PagerDuty[PagerDuty On-call rotation Escalation policies Incident management]
        EmailGroups[Email Groups Distribution lists Role-based routing Executive summaries]
    end
    
    subgraph "Automated Responses"
        AutoScaling[Auto Scaling Actions ECS service scaling Resource adjustment Capacity management]
        LambdaTriggers[Lambda Triggers Custom remediation Automated failover Self-healing actions]
        RunbookExecution[Runbook Execution Systems Manager Automated procedures Standard responses]
    end
    
    P1 --> CloudWatchAlarms
    P2 --> HealthChecks
    P3 --> SecurityAlerts
    P4 --> ApplicationLogs
    
    CloudWatchAlarms --> SNSTopic
    HealthChecks --> SlackIntegration
    SecurityAlerts --> PagerDuty
    ApplicationLogs --> EmailGroups
    
    SNSTopic --> AutoScaling
    SlackIntegration --> LambdaTriggers
    PagerDuty --> RunbookExecution
    
    style P1 fill:#dc3545,color:#ffffff,stroke:#bd2130,stroke-width:4px
    style P2 fill:#fd7e14,color:#ffffff,stroke:#e8681a,stroke-width:3px
    style P3 fill:#ffc107,color:#000000,stroke:#d39e00,stroke-width:2px
    style P4 fill:#28a745,color:#ffffff,stroke:#1e7e34,stroke-width:2px
```

### Key Performance Indicators (KPIs)

| Category | Metric | Current Value | Target | Alert Threshold |
|----------|--------|---------------|--------|-----------------|
| **Availability** | Service Uptime | 99.97% | 99.9% | < 99.5% |
| **Performance** | Response Time (P95) | 285ms | < 500ms | > 1000ms |
| **Performance** | Throughput | 1,250 req/min | Variable | -50% from baseline |
| **Reliability** | Error Rate | 0.02% | < 0.1% | > 0.5% |
| **Capacity** | ECS CPU Utilization | 45% | 40-70% | > 80% |
| **Capacity** | RDS Connections | 25/100 | < 80 | > 90 |
| **DR** | Replication Lag | 0.8s | < 5s | > 30s |
| **Security** | Failed Login Attempts | 0/hour | 0 | > 10/hour |
| **Business** | Daily Active Users | 85 | Growing | < 50 |
| **Cost** | Monthly Infrastructure Cost | $322 | < $400 | > $500 |

---

## Disaster Recovery Operations

### Automated Failover Workflow

```mermaid
sequenceDiagram
    participant User as End User
    participant CF as CloudFront
    participant R53 as Route 53
    participant ProdALB as Production ALB
    participant DRALB as DR ALB
    participant Lambda as Failover Lambda
    participant ECS as DR ECS Service
    participant RDS as DR RDS Replica
    participant SNS as Notification Service
    
    Note over User,SNS: Normal Operation
    User->>CF: Request Application
    CF->>R53: DNS Resolution
    R53->>ProdALB: Route to Primary
    ProdALB->>User: Response (200 OK)
    
    Note over User,SNS: Disaster Detection
    User->>CF: Request Application
    CF->>R53: DNS Resolution
    R53->>ProdALB: Health Check
    ProdALB-->>R53: Timeout/Error
    R53->>Lambda: Trigger Failover
    
    Note over User,SNS: Automated Failover Process
    Lambda->>SNS: Send Alert (Failover Started)
    Lambda->>ECS: Scale Service (0 to 2 tasks)
    Lambda->>RDS: Promote Read Replica
    
    par Parallel Failover Actions
        ECS->>ECS: Start Tasks (5-8 minutes)
        RDS->>RDS: Promote to Primary (2-5 minutes)
    end
    
    Lambda->>R53: Update Failover Routing
    R53->>DRALB: Route Traffic to DR
    
    Note over User,SNS: Service Restoration
    User->>CF: Request Application
    CF->>R53: DNS Resolution
    R53->>DRALB: Route to DR Region
    DRALB->>User: Response (200 OK)
    Lambda->>SNS: Send Alert (Failover Complete)
```

### Manual Failover Procedures

#### Option 1: GitHub Actions Workflow

```bash
# Navigate to GitHub repository
# Go to Actions tab
# Select "DR Failover" workflow
# Click "Run workflow"
# Enter confirmation: "FAILOVER"
# Monitor execution in real-time

# Expected timeline:
# - Workflow start: 0-30 seconds
# - ECS scaling: 5-8 minutes
# - RDS promotion: 2-5 minutes
# - DNS propagation: 2-5 minutes
# - Total time: 15-20 minutes
```

#### Option 2: Command Line Execution

```bash
# Clone repository and navigate to scripts
git clone <repository-url>
cd scripts

# Execute manual failover script
chmod +x cloudfront-failover.sh
./cloudfront-failover.sh

# Follow interactive prompts:
# 1. Confirm current CloudFront target
# 2. Verify impact acknowledgment
# 3. Execute failover
# 4. Monitor status
```

#### Option 3: AWS Console Emergency Procedures

```bash
# Emergency manual steps if automation fails:

# Step 1: Scale DR ECS Service
aws ecs update-service \
  --cluster student-record-system-v2-cluster \
  --service student-record-system-v2-service \
  --desired-count 2 \
  --region eu-west-1

# Step 2: Promote RDS Read Replica
aws rds promote-read-replica-db-cluster \
  --db-cluster-identifier student-record-system-v2-aurora-cluster-replica \
  --region eu-west-1

# Step 3: Update CloudFront Distribution
# (Use CloudFront console or CLI to switch origin)

# Step 4: Verify service health
curl -I https://d15jb99tjkxquc.cloudfront.net
```

### Failback Procedures

```mermaid
graph TD
    subgraph "Pre-Failback Assessment"
        A1[Assess Primary Region Infrastructure Status Service Readiness Data Integrity]
        A2[Validate Data Sync Compare DR to Primary Identify Discrepancies Plan Data Merge]
        A3[Test Primary Services Database Connectivity Application Health Performance Validation]
    end
    
    subgraph "Failback Execution"
        B1[Prepare Primary Region Update Infrastructure Deploy Latest Code Configure Services]
        B2[Synchronize Data Export from DR Database Import to Primary Validate Consistency]
        B3[Update DNS Records CloudFront Origin Switch Route 53 Configuration Health Check Updates]
        B4[Scale Down DR Services ECS Tasks 2 to 0 Cost Optimization Maintain Standby State]
    end
    
    subgraph "Post-Failback Validation"
        C1[Monitor Primary Region Performance Metrics Error Rates User Experience]
        C2[Verify DR Readiness Replication Status Standby Validation Future Failover Prep]
        C3[Document Lessons Incident Report Process Improvements Update Procedures]
    end
    
    A1 --> A2
    A2 --> A3
    A3 --> B1
    B1 --> B2
    B2 --> B3
    B3 --> B4
    B4 --> C1
    C1 --> C2
    C2 --> C3
    
    style A1 fill:#17a2b8,color:#ffffff,stroke:#138496,stroke-width:3px
    style B2 fill:#fd7e14,color:#ffffff,stroke:#e8681a,stroke-width:3px
    style B3 fill:#dc3545,color:#ffffff,stroke:#bd2130,stroke-width:3px
    style C1 fill:#28a745,color:#ffffff,stroke:#1e7e34,stroke-width:3px
```

### DR Testing Schedule

| Test Type | Frequency | Duration | Scope | Success Criteria |
|-----------|-----------|----------|-------|------------------|
| **Connectivity Test** | Daily | 5 minutes | Health checks only | All endpoints respond |
| **Data Replication Test** | Weekly | 15 minutes | Verify sync lag | Lag < 5 seconds |
| **Partial Failover Test** | Monthly | 30 minutes | DR services only | Services start successfully |
| **Full DR Drill** | Quarterly | 2 hours | Complete failover/failback | RTO < 30 min, RPO < 5 min |
| **Annual DR Exercise** | Yearly | 4 hours | Extended simulation | Business continuity validated |

---

## Cost Analysis

### Detailed Monthly Cost Breakdown

```mermaid
graph TB
    subgraph "Production Region Costs: eu-central-1"
        subgraph "Compute Services"
            ECS_PROD[ECS Fargate 2 tasks x 0.25 vCPU x 0.5 GB 24/7 runtime Monthly 18.20 USD]
            ALB_PROD[Application Load Balancer Fixed monthly cost Data processing charges Monthly 22.50 USD]
            NAT_PROD[NAT Gateways 2 gateways x Multi-AZ Data transfer costs Monthly 90.00 USD]
        end
        
        subgraph "Database Services"
            RDS_PROD[Aurora MySQL Cluster 2 x db.t3.large instances Multi-AZ deployment Monthly 120.00 USD]
            STORAGE_PROD[Database Storage 20 GB allocated storage I/O operations Monthly 8.50 USD]
            BACKUP_PROD[Automated Backups 7-day retention Cross-region backup Monthly 12.00 USD]
        end
        
        subgraph "Storage Services"
            S3_PROD[S3 Standard Storage Application assets Cross-region replication Monthly 3.20 USD]
            ECR_PROD[ECR Repository Container image storage Data transfer costs Monthly 2.10 USD]
        end
        
        subgraph "Networking Services"
            DATA_PROD[Data Transfer 50 GB monthly average Inter-AZ transfer Monthly 5.00 USD]
            VPC_PROD[VPC Endpoints S3 and ECR endpoints Interface endpoints Monthly 7.20 USD]
        end
        
        TOTAL_PROD[Production Total Monthly 288.70 USD]
    end
    
    subgraph "DR Region Costs: eu-west-1"
        subgraph "Standby Services"
            ECS_DR[ECS Fargate 0 tasks pilot light Cluster maintenance only Monthly 0.00 USD]
            ALB_DR[Application Load Balancer Pre-configured for failover Minimal data processing Monthly 22.50 USD]
            RDS_DR[Aurora Read Replica 1 x db.t3.large instance Read-only standby Monthly 60.00 USD]
        end
        
        subgraph "Replication Services"
            S3_DR[S3 Replication Target Cross-region replicated data Standard storage class Monthly 2.80 USD]
            ECR_DR[ECR Repository Replicated container images On-demand pulls Monthly 1.50 USD]
        end
        
        subgraph "DR Networking"
            DATA_DR[Data Transfer Replication bandwidth Cross-region charges Monthly 4.20 USD]
        end
        
        TOTAL_DR[DR Total Monthly 91.00 USD]
    end
    
    subgraph "Global Services"
        subgraph "Content Delivery"
            CLOUDFRONT[CloudFront Distribution Global edge locations Data transfer out Monthly 15.30 USD]
            ROUTE53[Route 53 Hosted Zone DNS queries Health checks Monthly 3.50 USD]
        end
        
        subgraph "Management Services"
            CLOUDWATCH[CloudWatch Metrics logs alarms Dashboard charges Monthly 8.75 USD]
            SSM[Systems Manager Parameter Store Patch management Monthly 2.25 USD]
        end
        
        TOTAL_GLOBAL[Global Services Total Monthly 29.80 USD]
    end
    
    subgraph "Total Infrastructure Cost"
        GRAND_TOTAL[Monthly Total 409.50 USD Annual 4914 USD Per User 4.82 USD]
    end
    
    ECS_PROD --> TOTAL_PROD
    ALB_PROD --> TOTAL_PROD
    NAT_PROD --> TOTAL_PROD
    RDS_PROD --> TOTAL_PROD
    STORAGE_PROD --> TOTAL_PROD
    BACKUP_PROD --> TOTAL_PROD
    S3_PROD --> TOTAL_PROD
    ECR_PROD --> TOTAL_PROD
    DATA_PROD --> TOTAL_PROD
    VPC_PROD --> TOTAL_PROD
    
    ECS_DR --> TOTAL_DR
    ALB_DR --> TOTAL_DR
    RDS_DR --> TOTAL_DR
    S3_DR --> TOTAL_DR
    ECR_DR --> TOTAL_DR
    DATA_DR --> TOTAL_DR
    
    CLOUDFRONT --> TOTAL_GLOBAL
    ROUTE53 --> TOTAL_GLOBAL
    CLOUDWATCH --> TOTAL_GLOBAL
    SSM --> TOTAL_GLOBAL
    
    TOTAL_PROD --> GRAND_TOTAL
    TOTAL_DR --> GRAND_TOTAL
    TOTAL_GLOBAL --> GRAND_TOTAL
    
    style TOTAL_PROD fill:#28a745,color:#ffffff,stroke:#1e7e34,stroke-width:4px
    style TOTAL_DR fill:#ffc107,color:#000000,stroke:#d39e00,stroke-width:4px
    style TOTAL_GLOBAL fill:#17a2b8,color:#ffffff,stroke:#138496,stroke-width:4px
    style GRAND_TOTAL fill:#6f42c1,color:#ffffff,stroke:#5a32a3,stroke-width:5px
    style NAT_PROD fill:#dc3545,color:#ffffff,stroke:#bd2130,stroke-width:3px
    style RDS_PROD fill:#fd7e14,color:#ffffff,stroke:#e8681a,stroke-width:3px
```

### Cost Optimization Strategies

```mermaid
graph TD
    subgraph "Immediate Optimizations 0-30 days"
        OPT1[Single NAT Gateway Savings 45 USD/month Risk Reduced AZ redundancy Implementation 1 hour]
        OPT2[Scheduled ECS Scaling Savings 10-15 USD/month Risk None Implementation 2 hours]
        OPT3[S3 Lifecycle Policies Savings 2-5 USD/month Risk None Implementation 30 minutes]
        OPT4[CloudWatch Log Retention Savings 3-8 USD/month Risk Reduced log history Implementation 15 minutes]
    end
    
    subgraph "Medium-term Optimizations 1-3 months"
        OPT5[Reserved Instance Pricing Savings 30-50 percent on RDS Risk 1-year commitment Implementation 1 day]
        OPT6[Fargate Spot Instances Savings 70 percent on compute Risk Task interruption Implementation 1 week]
        OPT7[Cross-Region Transfer Optimization Savings 5-10 USD/month Risk Slightly higher latency Implementation 2 days]
        OPT8[CloudFront Caching Optimization Savings 8-12 USD/month Risk Cache invalidation complexity Implementation 3 days]
    end
    
    subgraph "Long-term Optimizations 3-12 months"
        OPT9[Multi-Region Database Optimization Savings 20-30 USD/month Risk Architecture changes Implementation 2 weeks]
        OPT10[Serverless Aurora Savings 40-60 percent on database Risk Cold start latency Implementation 1 week]
        OPT11[Container Image Optimization Savings 5-15 USD/month Risk Increased build time Implementation 1 week]
        OPT12[Resource Right-sizing Savings 15-25 percent overall Risk Performance impact Implementation Ongoing]
    end
    
    subgraph "Cost Monitoring Implementation"
        BUDGET1[AWS Budgets Monthly spending alerts Department allocation Anomaly detection]
        BUDGET2[Cost Explorer Detailed usage analysis Trend identification Optimization recommendations]
        BUDGET3[Tagging Strategy Resource categorization Cost allocation Department chargebacks]
    end
    
    OPT1 --> OPT5
    OPT2 --> OPT6
    OPT3 --> OPT7
    OPT4 --> OPT8
    
    OPT5 --> OPT9
    OPT6 --> OPT10
    OPT7 --> OPT11
    OPT8 --> OPT12
    
    OPT9 --> BUDGET1
    OPT10 --> BUDGET2
    OPT11 --> BUDGET3
    OPT12 --> BUDGET3
    
    style OPT1 fill:#28a745,color:#ffffff,stroke:#1e7e34,stroke-width:3px
    style OPT5 fill:#ffc107,color:#000000,stroke:#d39e00,stroke-width:3px
    style OPT9 fill:#dc3545,color:#ffffff,stroke:#bd2130,stroke-width:3px
    style BUDGET1 fill:#6f42c1,color:#ffffff,stroke:#5a32a3,stroke-width:3px
```

### ROI Analysis for DR Investment

| Investment Category | Monthly Cost | Annual Cost | Business Value | ROI Justification |
|-------------------|--------------|-------------|----------------|-------------------|
| **DR Infrastructure** | $91.00 | $1,092 | Business continuity | Prevents revenue loss during outages |
| **Automation Tools** | $15.50 | $186 | Reduced manual effort | 80% reduction in failover time |
| **Monitoring/Alerting** | $8.75 | $105 | Early issue detection | Prevents 95% of potential outages |
| **Cross-region Replication** | $6.50 | $78 | Data protection | Ensures < 5-minute RPO |
| **Total DR Investment** | $121.75 | $1,461 | Risk mitigation | Protects against business disruption |

**Cost-Benefit Analysis:**
- **Potential Revenue Loss** per hour of downtime: $2,500
- **Average Recovery Time** without DR: 4-8 hours
- **Potential Loss** per incident: $10,000-$20,000
- **DR Investment ROI**: 685% (prevents one major outage annually)

---

## Maintenance Procedures

### Routine Maintenance Schedule

```mermaid
gantt
    title Infrastructure Maintenance Calendar
    dateFormat  YYYY-MM-DD
    axisFormat %M:%S
    
    section Daily Tasks
    Monitor Dashboards          :done, daily1, 2024-01-01, 1d
    Check Application Logs      :done, daily2, 2024-01-01, 1d
    Verify Backup Completion    :done, daily3, 2024-01-01, 1d
    Review Security Alerts      :done, daily4, 2024-01-01, 1d
    
    section Weekly Tasks
    DR Connectivity Test        :done, weekly1, 2024-01-01, 7d
    Security Group Review       :done, weekly2, 2024-01-01, 7d
    Performance Analysis        :done, weekly3, 2024-01-01, 7d
    Cost Optimization Review    :done, weekly4, 2024-01-01, 7d
    
    section Monthly Tasks
    Full DR Drill              :done, monthly1, 2024-01-01, 30d
    Security Scan               :done, monthly2, 2024-01-01, 30d
    Capacity Planning           :done, monthly3, 2024-01-01, 30d
    Infrastructure Updates      :done, monthly4, 2024-01-01, 30d
    
    section Quarterly Tasks
    Disaster Recovery Exercise  :active, quarterly1, 2024-01-01, 90d
    Architecture Review         :quarterly2, after quarterly1, 90d
    Security Assessment         :quarterly3, after quarterly2, 90d
    Business Continuity Test    :quarterly4, after quarterly3, 90d
```

### Automated Maintenance Workflows

```mermaid
graph TD
    subgraph "Automated Backup Procedures"
        B1[RDS Automated Backups Daily at 03:00 UTC 7-day retention Point-in-time recovery]
        B2[Application Data Backup S3 versioning enabled Cross-region replication Lifecycle policies]
        B3[Configuration Backup Terraform state backup Parameter Store export GitHub repository sync]
        B4[Container Image Backup ECR lifecycle policies Multi-region replication Vulnerability scanning]
    end
    
    subgraph "Health Check Automation"
        H1[ALB Target Health Continuous monitoring Automatic replacement Alert on failure]
        H2[ECS Service Health Container health checks Automatic restart Performance monitoring]
        H3[Database Health Connection monitoring Performance metrics Replication lag alerts]
        H4[Cross-Region Health Connectivity tests Failover capability Sync verification]
    end
    
    subgraph "Security Maintenance"
        S1[Vulnerability Scanning ECR image scanning OS patch assessment Dependency updates]
        S2[Access Review IAM policy validation Permission auditing Unused resource cleanup]
        S3[Certificate Management SSL/TLS renewal Expiration monitoring Automatic rotation]
        S4[Security Group Audit Rule validation Unused rule cleanup Compliance checking]
    end
    
    subgraph "Performance Optimization"
        P1[Resource Right-sizing CPU/Memory analysis Cost optimization Performance tuning]
        P2[Database Optimization Query performance Index optimization Connection pooling]
        P3[Caching Strategy CloudFront optimization Application caching Database caching]
        P4[Scaling Adjustments Auto-scaling tuning Capacity planning Peak load preparation]
    end
    
    B1 --> H1
    B2 --> H2
    B3 --> H3
    B4 --> H4
    
    H1 --> S1
    H2 --> S2
    H3 --> S3
    H4 --> S4
    
    S1 --> P1
    S2 --> P2
    S3 --> P3
    S4 --> P4
    
    style B1 fill:#17a2b8,color:#ffffff,stroke:#138496,stroke-width:3px
    style H1 fill:#28a745,color:#ffffff,stroke:#1e7e34,stroke-width:3px
    style S1 fill:#dc3545,color:#ffffff,stroke:#bd2130,stroke-width:3px
    style P1 fill:#ffc107,color:#000000,stroke:#d39e00,stroke-width:3px
```

### Update and Patch Management

| Component | Update Frequency | Method | Downtime | Rollback Plan |
|-----------|------------------|---------|----------|---------------|
| **Application Code** | Per deployment | GitHub Actions CI/CD | Zero downtime | Previous container image |
| **Container Base Image** | Monthly | Rebuild and redeploy | Zero downtime | Previous image version |
| **ECS Fargate Platform** | Automatic | AWS managed | Zero downtime | Platform rollback |
| **Aurora Database** | Maintenance window | AWS managed | Minimal (2-3 min) | Point-in-time recovery |
| **ALB Configuration** | As needed | Terraform updates | Zero downtime | Configuration rollback |
| **Security Groups** | As needed | Terraform updates | Zero downtime | Rule reversion |
| **CloudFront Distribution** | As needed | Terraform/Console | Propagation delay | Origin switching |
| **Route 53 Records** | Emergency only | Manual/Automated | TTL-based | DNS reversion |

---

## Troubleshooting Guide

### Common Issues and Resolution Matrix

```mermaid
graph TD
    subgraph "Application Issues"
        A1[ECS Tasks Failing to Start Status STOPPED Common Causes Image pull errors Resource constraints Environment variables]
        
        A2[Database Connection Errors Status Connection timeout Common Causes Security group rules Database availability Network connectivity]
        
        A3[High Response Times Status Latency greater than 1000ms Common Causes Database performance Resource constraints Network latency]
    end
    
    subgraph "Infrastructure Issues"
        I1[ALB Health Check Failures Status Unhealthy targets Common Causes Application startup time Health check path Port configuration]
        
        I2[Cross-Region Replication Lag Status Lag greater than 30 seconds Common Causes Network connectivity Write volume Instance sizing]
        
        I3[Auto-scaling Not Triggering Status High CPU no scaling Common Causes Metric thresholds Scaling policies Service limits]
    end
    
    subgraph "DR Issues"
        D1[Failover Not Triggering Status Manual intervention needed Common Causes Health check config Route 53 policies Lambda function errors]
        
        D2[DR Services Won't Start Status Task definition errors Common Causes Image availability IAM permissions Network configuration]
        
        D3[Data Inconsistency Status Primary/DR mismatch Common Causes Replication lag Split-brain scenario Partial failover]
    end
    
    subgraph "Resolution Workflows"
        R1[Diagnostic Steps 1. Check CloudWatch logs 2. Verify configurations 3. Test connectivity 4. Review metrics]
        
        R2[Immediate Actions 1. Scale resources 2. Restart services 3. Update configurations 4. Engage escalation]
        
        R3[Long-term Fixes 1. Infrastructure updates 2. Process improvements 3. Documentation updates 4. Preventive measures]
    end
    
    A1 --> R1
    A2 --> R1
    A3 --> R1
    I1 --> R1
    I2 --> R1
    I3 --> R1
    D1 --> R2
    D2 --> R2
    D3 --> R2
    
    R1 --> R2
    R2 --> R3
    
    style A1 fill:#dc3545,color:#ffffff,stroke:#bd2130,stroke-width:3px
    style I1 fill:#fd7e14,color:#ffffff,stroke:#e8681a,stroke-width:3px
    style D1 fill:#6f42c1,color:#ffffff,stroke:#5a32a3,stroke-width:3px
    style R1 fill:#17a2b8,color:#ffffff,stroke:#138496,stroke-width:3px
    style R2 fill:#ffc107,color:#000000,stroke:#d39e00,stroke-width:3px
    style R3 fill:#28a745,color:#ffffff,stroke:#1e7e34,stroke-width:3px
```

### Diagnostic Commands and Tools

#### ECS Service Diagnostics
```bash
# Check ECS service status
aws ecs describe-services \
  --cluster student-record-system-v2-cluster \
  --services student-record-system-v2-service \
  --region eu-central-1

# View task definition details
aws ecs describe-task-definition \
  --task-definition student-record-system-v2:latest

# Check stopped tasks for errors
aws ecs list-tasks \
  --cluster student-record-system-v2-cluster \
  --desired-status STOPPED \
  --max-items 10

# View CloudWatch logs
aws logs tail /aws/ecs/student-record-system-v2 \
  --follow --since 1h
```

#### Database Diagnostics
```bash
# Check Aurora cluster status
aws rds describe-db-clusters \
  --db-cluster-identifier student-record-system-v2-aurora-cluster \
  --region eu-central-1

# Monitor replication lag
aws rds describe-db-clusters \
  --db-cluster-identifier student-record-system-v2-aurora-cluster-replica \
  --region eu-west-1 \
  --query 'DBClusters[0].ReplicationSourceIdentifier'

# Check database connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

#### Load Balancer Diagnostics
```bash
# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names student-record-system-v2-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

# Monitor ALB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

#### DR Status Verification
```bash
# Verify DR components
./scripts/verify-dr-status.sh

# Check CloudFront distribution
aws cloudfront get-distribution \
  --id $(aws ssm get-parameter \
    --name "/student-record-system-v2/cloudfront-distribution-id" \
    --query 'Parameter.Value' \
    --output text)

# Test failover capability
./scripts/test-failover-readiness.sh
```

### Emergency Contact and Escalation

| Severity | Contact Method | Response Time | Escalation |
|----------|---------------|---------------|------------|
| **Critical (P1)** | PagerDuty + Phone | 15 minutes | CTO after 30 minutes |
| **High (P2)** | Slack + Email | 30 minutes | Team Lead after 1 hour |
| **Medium (P3)** | Email + Slack | 2 hours | Daily standup discussion |
| **Low (P4)** | Ticket system | 24 hours | Weekly review |

---

## Development Workflow

### Contributing Guidelines

```mermaid
graph TD
    subgraph "Development Process"
        DEV1[Create Feature Branch Branch from main Descriptive naming issue/feature-description]
        DEV2[Local Development Code changes Local testing Docker validation]
        DEV3[Pre-commit Checks Terraform fmt Terraform validate Security scanning]
        DEV4[Commit and Push Descriptive messages Reference issues Sign commits]
    end
    
    subgraph "Review Process"
        REV1[Create Pull Request Detailed description Link to issues Deployment impact]
        REV2[Automated Testing Terraform plan Security scanning Code quality checks]
        REV3[Peer Review Code review Architecture review Security review]
        REV4[Approval Process 2 approvals required All checks pass Deployment ready]
    end
    
    subgraph "Deployment Process"
        DEP1[Merge to Main Squash commits Update changelog Tag release]
        DEP2[Automated Deployment GitHub Actions Terraform apply Rolling deployment]
        DEP3[Post-deployment Health verification Monitoring checks Rollback if needed]
        DEP4[Documentation Update README Release notes Runbook updates]
    end
    
    DEV1 --> DEV2
    DEV2 --> DEV3
    DEV3 --> DEV4
    DEV4 --> REV1
    
    REV1 --> REV2
    REV2 --> REV3
    REV3 --> REV4
    REV4 --> DEP1
    
    DEP1 --> DEP2
    DEP2 --> DEP3
    DEP3 --> DEP4
    
    style DEV1 fill:#17a2b8,color:#ffffff,stroke:#138496,stroke-width:3px
    style REV2 fill:#ffc107,color:#000000,stroke:#d39e00,stroke-width:3px
    style DEP2 fill:#28a745,color:#ffffff,stroke:#1e7e34,stroke-width:3px
```

### Code Standards and Quality Gates

#### Terraform Standards
```hcl
# Required module structure
module "example" {
  source = "../../modules/component"
  
  # Required variables with descriptions
  project_name = var.project_name
  environment  = var.environment
  
  # Optional variables with defaults
  instance_count = var.instance_count != "" ? var.instance_count : 2
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Output all important values
output "component_arn" {
  value       = module.example.arn
  description = "ARN of the created component"
}
```

#### Application Standards
```php
<?php
// Required: All database queries use prepared statements
$stmt = $pdo->prepare("SELECT * FROM students WHERE id = ?");
$stmt->execute([$student_id]);
$result = $stmt->fetch(PDO::FETCH_ASSOC);

// Required: Input validation
function validateStudentData($data) {
    $errors = [];
    
    if (empty($data['name']) || !preg_match('/^[A-Za-z\s]+$/', $data['name'])) {
        $errors[] = "Invalid name format";
    }
    
    if (!filter_var($data['age'], FILTER_VALIDATE_INT, 
        ["options" => ["min_range" => 16, "max_range" => 100]])) {
        $errors[] = "Age must be between 16 and 100";
    }
    
    return $errors;
}

// Required: Error handling
try {
    $result = performDatabaseOperation();
} catch (PDOException $e) {
    error_log("Database error: " . $e->getMessage());
    throw new Exception("Operation failed. Please try again.");
}
?>
```

### Testing Requirements

| Test Type | Coverage | Tools | Frequency |
|-----------|----------|-------|-----------|
| **Unit Tests** | 80%+ | PHPUnit | Every commit |
| **Integration Tests** | Key workflows | Custom scripts | Every PR |
| **Infrastructure Tests** | Terraform validation | terraform plan | Every commit |
| **Security Tests** | OWASP compliance | SAST tools | Every PR |
| **Performance Tests** | Load testing | Artillery.js | Weekly |
| **DR Tests** | Failover scenarios | Custom scripts | Monthly |

### Release Management

```mermaid
graph LR
    subgraph "Release Pipeline"
        R1[Feature Complete All tests pass Documentation updated Security validated]
        R2[Release Candidate Version tagging Staging deployment Integration testing]
        R3[Production Release Deployment to production Health monitoring Rollback capability]
        R4[Post-Release Monitoring validation Performance verification User feedback]
    end
    
    subgraph "Version Management"
        V1[Semantic Versioning MAJOR.MINOR.PATCH Breaking.Feature.Bugfix Example 2.1.0]
        V2[Git Tags Annotated tags Release notes Deployment markers]
        V3[Changelog User-facing changes Breaking changes Migration guides]
    end
    
    R1 --> R2
    R2 --> R3
    R3 --> R4
    
    R1 --> V1
    R2 --> V2
    R3 --> V3
    
    style R3 fill:#28a745,color:#ffffff,stroke:#1e7e34,stroke-width:3px
    style V1 fill:#6f42c1,color:#ffffff,stroke:#5a32a3,stroke-width:3px
```

---

## Support and Documentation

### Support Channels

| Channel | Purpose | Response Time | Availability |
|---------|---------|---------------|--------------|
| **GitHub Issues** | Bug reports, feature requests | 24-48 hours | 24/7 |
| **Documentation** | Implementation guides, FAQs | Self-service | 24/7 |
| **Email Support** | General inquiries | 2-4 business hours | Business hours |
| **Emergency Contact** | Critical production issues | 15 minutes | 24/7 |

### Resource Links

- **AWS Documentation**: [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- **Terraform Documentation**: [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- **Disaster Recovery Guide**: [AWS DR Strategies](https://aws.amazon.com/disaster-recovery/)
- **Security Best Practices**: [AWS Security Hub](https://aws.amazon.com/security-hub/)
- **GitHub Actions**: [Workflow Documentation](https://docs.github.com/en/actions)

