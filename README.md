# 🚀 Freelancer Escrow & Dispute Resolution Smart Contract

A decentralized escrow system built on Stacks blockchain that protects both clients and freelancers through secure fund management and community-driven dispute resolution.

## 🌟 Features

- **💰 Secure Escrow**: Funds are locked in the contract until work completion
- **👥 Job Management**: Complete workflow from job creation to completion
- **⚖️ Dispute Resolution**: Community arbitrators vote on disputed jobs
- **🔒 Multi-State Protection**: Robust state management prevents unauthorized actions
- **📝 Application System**: Freelancers can apply for jobs with messages

## 🏗️ Contract Architecture

### Job States
- `CREATED` (0): Job posted, waiting for freelancer assignment
- `FUNDED` (1): Client has deposited funds into escrow
- `IN_PROGRESS` (2): Freelancer is working on the job
- `COMPLETED` (3): Work submitted, awaiting client approval
- `DISPUTED` (4): Dispute initiated, awaiting arbitration
- `RESOLVED` (5): Job completed and funds released
- `CANCELLED` (6): Job cancelled by client or dispute resolved in client's favor

## 📋 Usage Instructions

### For Clients 👨‍💼

1. **Create a Job**
   ```clarity
   (contract-call? .freelancer-escrow create-job "Website Design" "Create a modern portfolio website" u1000000 u1672531200)
   ```

2. **Assign Freelancer**
   ```clarity
   (contract-call? .freelancer-escrow assign-freelancer u1 'SP1FREELANCER...)
   ```

3. **Fund the Job**
   ```clarity
   (contract-call? .freelancer-escrow fund-job u1)
   ```

4. **Approve Completed Work**
   ```clarity
   (contract-call? .freelancer-escrow approve-work u1)
   ```

5. **Initiate Dispute (if needed)**
   ```clarity
   (contract-call? .freelancer-escrow initiate-dispute u1 "Work does not meet requirements")
   ```

### For Freelancers 👩‍💻

1. **Apply for Job**
   ```clarity
   (contract-call? .freelancer-escrow apply-for-job u1 "I have 5 years experience in web design")
   ```

2. **Start Work**
   ```clarity
   (contract-call? .freelancer-escrow start-work u1)
   ```

3. **Submit Completed Work**
   ```clarity
   (contract-call? .freelancer-escrow submit-work u1)
   ```

4. **Initiate Dispute (if needed)**
   ```clarity
   (contract-call? .freelancer-escrow initiate-dispute u1 "Client is not responding to communications")
   ```

### For Arbitrators ⚖️

1. **Register as Arbitrator**
   ```clarity
   (contract-call? .freelancer-escrow register-arbitrator)
   ```

2. **Vote on Disputes**
   ```clarity
   (contract-call? .freelancer-escrow vote-on-dispute u1 'SP1CLIENT...)
   ```

3. **Resolve Dispute** (after voting period ends)
   ```clarity
   (contract-call? .freelancer-escrow resolve-dispute u1)
   ```

## 🔍 Read-Only Functions

### Get Job Information
```clarity
(contract-call? .freelancer-escrow get-job u1)
```

### Check Dispute Details
```clarity
(contract-call? .freelancer-escrow get-dispute u1)
```

### View Job Applications
```clarity
(contract-call? .freelancer-escrow get-job-application u1 'SP1FREELANCER...)
```

### Check Arbitrator Status
```clarity
(contract-call? .freelancer-escrow is-arbitrator 'SP1ARBITRATOR...)
```

## ⚙️ Configuration

- **Dispute Duration**: 1008 blocks (~1 week)
- **Minimum Arbitrators**: 3 votes required for dispute resolution
- **Job Counter**: Tracks total number of jobs created
- **Dispute Counter**: Tracks total number of disputes

## 🚨 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 1001 | ERR-UNAUTHORIZED | User lacks permission for this action |
| 1002 | ERR-INVALID-JOB | Job does not exist or invalid job ID |
| 1003 | ERR-INSUFFICIENT-FUNDS | Not enough funds for the operation |
| 1004 | ERR-INVALID-STATE | Invalid state transition attempted |
| 1005 | ERR-NOT-PARTICIPANT | User is not part of this job |
| 1006 | ERR-ALREADY-VOTED | Arbitrator has already voted on this dispute |
| 1007 | ERR-DISPUTE-TIMEOUT | Dispute voting period has ended |
| 1008 | ERR-INVALID-AMOUNT | Amount must be greater than zero |

## 🔐 Security Features

- ✅ Funds locked in contract until resolution
- ✅ State-based access control
- ✅ Community arbitration prevents centralized control
- ✅ Deadline enforcement for disputes
- ✅ Duplicate vote prevention
- ✅ Principal validation for all participants

## 🛠️ Development

### Prerequisites
- Clarinet CLI
- Stacks wallet for testing

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy
```

## 📄 License

This project is open source and available under the MIT License.

---

Built with ❤️ for the decentralized gig economy on Stacks blockchain 🚀
