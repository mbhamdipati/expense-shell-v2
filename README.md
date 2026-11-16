# Expense V2 — Automated AWS Deployment

An end-to-end automation script to provision and configure the **Expense V2** application infrastructure on AWS without needing to manually log in to the AWS Management Console.

---

## Prerequisites

* **AWS CLI** installed and configured (`aws configure`) with valid IAM credentials.
* **SSH Key Pair** configured in your target AWS region to access instances if needed.
* **Bash** shell environment (Linux, macOS, or Git Bash / WSL on Windows).

---
## Configuration (`.env`)
This project uses a `.env` file to manage infrastructure settings and domain configuration as a single source of truth.
### 1. Create your `.env` file
Copy the provided template:
```bash
cp .env.example .env
```
### 2. Configure your parameters
Open `.env` and set your AWS parameters:
```env
AMI_ID="ami-0055977a6e828a4f4"
INSTANCE_TYPE="t3.micro"
DOMAIN_NAME="devops.store"
HOSTED_ZONE_ID="Z0579378K5AL0YOAZ116"
```
| Variable | Description | Example |
| :--- | :--- | :--- |
| `AMI_ID` | Target AMI ID in your selected AWS region (RHEL 9 / AlmaLinux) | `ami-0055977a6e828a4f4` |
| `INSTANCE_TYPE` | EC2 instance size | `t3.micro` |
| `DOMAIN_NAME` | Your base domain name registered in Route 53 | `devops.store` |
| `HOSTED_ZONE_ID` | AWS Route 53 Hosted Zone ID for your domain | `Z0579378K5AL0YOAZ116` |
> [!NOTE]
> * When `main.sh` executes, it automatically injects these `.env` variables into each instance's user-data script (`database.sh`, `backend.sh`, `frontend.sh`).
> * The `.env` file is excluded from Git via `.gitignore` to prevent committing account-specific IDs.

---

## Usage

### 1. Argument Format

Pass security group rules and instance configurations as quoted arguments in the following format:

```text
"{instance}:{description}:{port}:{IP_or_SG_name}"
```

| Parameter | Description | Example |
| :--- | :--- | :--- |
| `instance` | Name of the instance / security group tier (`common`, `frontend`, `backend`, `database`) | `frontend` |
| `description` | Description for the inbound security group rule | `allow public` |
| `port` | Port number to allow inbound traffic | `80` |
| `IP/SG_name` | Source CIDR block, `MY_IP` (auto-detects your public IP), or a source Security Group name | `0.0.0.0/0` or `frontend` |

---

### 2. Run the Deployment Script

Execute `main.sh` with your required security group and instance arguments:

```bash
bash main.sh \
  "common:allows ssh traffic:22:MY_IP" \
  "frontend:allow public:80:0.0.0.0/0" \
  "backend:allow frontend traffic:8080:frontend" \
  "database:allow backend traffic:3306:backend"
```

---

## Deployment Workflow

1. **Wait for Provisioning (~5 Minutes):**
   Once you run the script, wait approximately **5 minutes** for all instances, security groups, Route 53 records, and application packages to finish installing automatically. No manual intervention in the AWS Console is required.

2. **Verify Logs (Optional):**
   All instance public and private IP addresses are printed in the terminal at the end of the script execution. If you want to verify the setup, SSH into any instance and inspect the installation logs:
   ```bash
   ssh -i <your-key.pem> ec2-user@<INSTANCE_PUBLIC_IP>
   ```

3. **Access the Application:**
   Open your browser and navigate to your configured **domain name** or the **frontend public IP**:
   ```text
   http://<YOUR_DOMAIN_NAME>
   # or
   http://<FRONTEND_PUBLIC_IP>
   ```
