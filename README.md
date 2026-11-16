# Expense V2 — Automated AWS Deployment

An end-to-end automation script to provision and configure the **Expense V2** application infrastructure on AWS without needing to manually log in to the AWS Management Console.

---

## Prerequisites

* **AWS CLI** installed and configured (`aws configure`) with valid IAM credentials.
* **SSH Key Pair** configured in your target AWS region to access instances if needed.
* **Bash** shell environment (Linux, macOS, or Git Bash / WSL on Windows).

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
