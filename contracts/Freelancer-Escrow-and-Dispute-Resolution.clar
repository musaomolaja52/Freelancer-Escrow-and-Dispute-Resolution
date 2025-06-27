(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u1001))
(define-constant ERR-INVALID-JOB (err u1002))
(define-constant ERR-INSUFFICIENT-FUNDS (err u1003))
(define-constant ERR-INVALID-STATE (err u1004))
(define-constant ERR-NOT-PARTICIPANT (err u1005))
(define-constant ERR-ALREADY-VOTED (err u1006))
(define-constant ERR-DISPUTE-TIMEOUT (err u1007))
(define-constant ERR-INVALID-AMOUNT (err u1008))

(define-constant JOB-STATE-CREATED u0)
(define-constant JOB-STATE-FUNDED u1)
(define-constant JOB-STATE-IN-PROGRESS u2)
(define-constant JOB-STATE-COMPLETED u3)
(define-constant JOB-STATE-DISPUTED u4)
(define-constant JOB-STATE-RESOLVED u5)
(define-constant JOB-STATE-CANCELLED u6)

(define-constant DISPUTE-DURATION u1008)
(define-constant MIN-ARBITRATORS u3)

(define-data-var job-counter uint u0)
(define-data-var dispute-counter uint u0)

(define-map jobs
  uint
  {
    client: principal,
    freelancer: principal,
    amount: uint,
    title: (string-ascii 100),
    description: (string-ascii 500),
    state: uint,
    created-at: uint,
    deadline: uint
  }
)

(define-map disputes
  uint
  {
    job-id: uint,
    initiator: principal,
    reason: (string-ascii 300),
    created-at: uint,
    deadline: uint,
    votes-for-client: uint,
    votes-for-freelancer: uint,
    resolved: bool
  }
)

(define-map arbitrators principal bool)

(define-map dispute-votes
  { dispute-id: uint, arbitrator: principal }
  { voted-for: principal, voted-at: uint }
)

(define-map job-applications
  { job-id: uint, freelancer: principal }
  { applied-at: uint, message: (string-ascii 200) }
)

(define-public (register-arbitrator)
  (begin
    (map-set arbitrators tx-sender true)
    (ok true)
  )
)

(define-public (create-job (title (string-ascii 100)) (description (string-ascii 500)) (amount uint) (deadline uint))
  (let ((job-id (+ (var-get job-counter) u1)))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> deadline (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR-INVALID-STATE)) ERR-INVALID-STATE)   (var-set job-counter job-id)
    (map-set jobs job-id
      {
        client: tx-sender,
        freelancer: 'SP000000000000000000002Q6VF78,
        amount: amount,
        title: title,
        description: description,
        state: JOB-STATE-CREATED,
        created-at: (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR-INVALID-STATE),
        deadline: deadline
      }
    )
    (ok job-id)
  )
)

(define-public (apply-for-job (job-id uint) (message (string-ascii 200)))
  (let ((job-data (unwrap! (map-get? jobs job-id) ERR-INVALID-JOB)))
    (asserts! (is-eq (get state job-data) JOB-STATE-CREATED) ERR-INVALID-STATE)
    (asserts! (not (is-eq tx-sender (get client job-data))) ERR-UNAUTHORIZED)
    (map-set job-applications { job-id: job-id, freelancer: tx-sender }
      {
        applied-at: (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR-INVALID-STATE),
        message: message
      }
    )
    (ok true)
  )
)

(define-public (assign-freelancer (job-id uint) (freelancer principal))
  (let ((job-data (unwrap! (map-get? jobs job-id) ERR-INVALID-JOB)))
    (asserts! (is-eq tx-sender (get client job-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state job-data) JOB-STATE-CREATED) ERR-INVALID-STATE)
    (map-set jobs job-id (merge job-data { freelancer: freelancer }))
    (ok true)
  )
)

(define-public (fund-job (job-id uint))
  (let ((job-data (unwrap! (map-get? jobs job-id) ERR-INVALID-JOB)))
    (asserts! (is-eq tx-sender (get client job-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state job-data) JOB-STATE-CREATED) ERR-INVALID-STATE)
    (asserts! (not (is-eq (get freelancer job-data) 'SP000000000000000000002Q6VF78)) ERR-INVALID-STATE)
    (try! (stx-transfer? (get amount job-data) tx-sender (as-contract tx-sender)))
    (map-set jobs job-id (merge job-data { state: JOB-STATE-FUNDED }))
    (ok true)
  )
)

(define-public (start-work (job-id uint))
  (let ((job-data (unwrap! (map-get? jobs job-id) ERR-INVALID-JOB)))
    (asserts! (is-eq tx-sender (get freelancer job-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state job-data) JOB-STATE-FUNDED) ERR-INVALID-STATE)
    (map-set jobs job-id (merge job-data { state: JOB-STATE-IN-PROGRESS }))
    (ok true)
  )
)

(define-public (submit-work (job-id uint))
  (let ((job-data (unwrap! (map-get? jobs job-id) ERR-INVALID-JOB)))
    (asserts! (is-eq tx-sender (get freelancer job-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state job-data) JOB-STATE-IN-PROGRESS) ERR-INVALID-STATE)
    (map-set jobs job-id (merge job-data { state: JOB-STATE-COMPLETED }))
    (ok true)
  )
)

(define-public (approve-work (job-id uint))
  (let ((job-data (unwrap! (map-get? jobs job-id) ERR-INVALID-JOB)))
    (asserts! (is-eq tx-sender (get client job-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state job-data) JOB-STATE-COMPLETED) ERR-INVALID-STATE)
    (try! (as-contract (stx-transfer? (get amount job-data) tx-sender (get freelancer job-data))))
    (map-set jobs job-id (merge job-data { state: JOB-STATE-RESOLVED }))
    (ok true)
  )
)

(define-public (initiate-dispute (job-id uint) (reason (string-ascii 300)))
  (let 
    (
      (job-data (unwrap! (map-get? jobs job-id) ERR-INVALID-JOB))
      (dispute-id (+ (var-get dispute-counter) u1))
      (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR-INVALID-STATE))
    )
    (asserts! (or (is-eq tx-sender (get client job-data)) (is-eq tx-sender (get freelancer job-data))) ERR-NOT-PARTICIPANT)
    (asserts! (or (is-eq (get state job-data) JOB-STATE-IN-PROGRESS) (is-eq (get state job-data) JOB-STATE-COMPLETED)) ERR-INVALID-STATE)
    (var-set dispute-counter dispute-id)
    (map-set disputes dispute-id
      {
        job-id: job-id,
        initiator: tx-sender,
        reason: reason,
        created-at: current-time,
        deadline: (+ current-time DISPUTE-DURATION),
        votes-for-client: u0,
        votes-for-freelancer: u0,
        resolved: false
      }
    )
    (map-set jobs job-id (merge job-data { state: JOB-STATE-DISPUTED }))
    (ok dispute-id)
  )
)

(define-public (vote-on-dispute (dispute-id uint) (vote-for principal))
  (let 
    (
      (dispute-data (unwrap! (map-get? disputes dispute-id) ERR-INVALID-JOB))
      (job-data (unwrap! (map-get? jobs (get job-id dispute-data)) ERR-INVALID-JOB))
      (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR-INVALID-STATE))
    )
    (asserts! (default-to false (map-get? arbitrators tx-sender)) ERR-UNAUTHORIZED)
    (asserts! (not (get resolved dispute-data)) ERR-INVALID-STATE)
    (asserts! (< current-time (get deadline dispute-data)) ERR-DISPUTE-TIMEOUT)
    (asserts! (or (is-eq vote-for (get client job-data)) (is-eq vote-for (get freelancer job-data))) ERR-UNAUTHORIZED)
    (asserts! (is-none (map-get? dispute-votes { dispute-id: dispute-id, arbitrator: tx-sender })) ERR-ALREADY-VOTED)
    
    (map-set dispute-votes { dispute-id: dispute-id, arbitrator: tx-sender }
      { voted-for: vote-for, voted-at: current-time }
    )
    
    (if (is-eq vote-for (get client job-data))
      (map-set disputes dispute-id (merge dispute-data { votes-for-client: (+ (get votes-for-client dispute-data) u1) }))
      (map-set disputes dispute-id (merge dispute-data { votes-for-freelancer: (+ (get votes-for-freelancer dispute-data) u1) }))
    )
    (ok true)
  )
)

(define-public (resolve-dispute (dispute-id uint))
  (let 
    (
      (dispute-data (unwrap! (map-get? disputes dispute-id) ERR-INVALID-JOB))
      (job-data (unwrap! (map-get? jobs (get job-id dispute-data)) ERR-INVALID-JOB))
      (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR-INVALID-STATE))
      (total-votes (+ (get votes-for-client dispute-data) (get votes-for-freelancer dispute-data)))
    )
    (asserts! (not (get resolved dispute-data)) ERR-INVALID-STATE)
    (asserts! (>= current-time (get deadline dispute-data)) ERR-INVALID-STATE)
    (asserts! (>= total-votes MIN-ARBITRATORS) ERR-INVALID-STATE)
    
    (map-set disputes dispute-id (merge dispute-data { resolved: true }))
    
    (if (> (get votes-for-client dispute-data) (get votes-for-freelancer dispute-data))
      (begin
        (try! (as-contract (stx-transfer? (get amount job-data) tx-sender (get client job-data))))
        (map-set jobs (get job-id dispute-data) (merge job-data { state: JOB-STATE-CANCELLED }))
      )
      (begin
        (try! (as-contract (stx-transfer? (get amount job-data) tx-sender (get freelancer job-data))))
        (map-set jobs (get job-id dispute-data) (merge job-data { state: JOB-STATE-RESOLVED }))
      )
    )
    (ok true)
  )
)

(define-public (cancel-job (job-id uint))
  (let ((job-data (unwrap! (map-get? jobs job-id) ERR-INVALID-JOB)))
    (asserts! (is-eq tx-sender (get client job-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state job-data) JOB-STATE-CREATED) ERR-INVALID-STATE)
    (map-set jobs job-id (merge job-data { state: JOB-STATE-CANCELLED }))
    (ok true)
  )
)

(define-read-only (get-job (job-id uint))
  (map-get? jobs job-id)
)

(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes dispute-id)
)

(define-read-only (get-job-application (job-id uint) (freelancer principal))
  (map-get? job-applications { job-id: job-id, freelancer: freelancer })
)

(define-read-only (is-arbitrator (user principal))
  (default-to false (map-get? arbitrators user))
)

(define-read-only (get-dispute-vote (dispute-id uint) (arbitrator principal))
  (map-get? dispute-votes { dispute-id: dispute-id, arbitrator: arbitrator })
)

(define-read-only (get-job-counter)
  (var-get job-counter)
)

(define-read-only (get-dispute-counter)
  (var-get dispute-counter)
)
