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

(define-constant ERR-NO-DATA (err u1009))

(define-data-var analytics-counter uint u0)

(define-data-var job-counter uint u0)
(define-data-var dispute-counter uint u0)

(define-constant MILESTONE-STATE-PENDING u0)
(define-constant MILESTONE-STATE-FUNDED u1)
(define-constant MILESTONE-STATE-COMPLETED u2)
(define-constant MILESTONE-STATE-APPROVED u3)

(define-constant ERR-RECURRING-INVALID (err u1010))
(define-constant ERR-RECURRING-NOT-DUE (err u1011))
(define-constant ERR-RECURRING-EXHAUSTED (err u1012))

(define-constant RECURRING-STATE-ACTIVE u0)
(define-constant RECURRING-STATE-PAUSED u1)
(define-constant RECURRING-STATE-CANCELLED u2)
(define-constant RECURRING-STATE-COMPLETED u3)

(define-constant BONUS-STATE-PENDING u0)
(define-constant BONUS-STATE-LOCKED u1)
(define-constant BONUS-STATE-CLAIMED u2)
(define-constant BONUS-STATE-REFUNDED u3)

(define-constant ERR-BONUS-EXISTS (err u2001))
(define-constant ERR-BONUS-INVALID (err u2002))
(define-constant ERR-BONUS-NOT-ELIGIBLE (err u2003))
(define-constant ERR-BONUS-ALREADY-CLAIMED (err u2004))

(define-data-var recurring-counter uint u0)

(define-data-var milestone-counter uint u0)

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

(define-map freelancer-reputation
  principal
  {
    total-jobs: uint,
    completed-jobs: uint,
    total-rating: uint,
    rating-count: uint,
    last-updated: uint
  }
)

(define-public (rate-freelancer (job-id uint) (rating uint))
  (let ((job-data (unwrap! (map-get? jobs job-id) ERR-INVALID-JOB)))
    (asserts! (is-eq tx-sender (get client job-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state job-data) JOB-STATE-RESOLVED) ERR-INVALID-STATE)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-AMOUNT)
    (let 
      (
        (freelancer (get freelancer job-data))
        (current-rep (default-to 
          { total-jobs: u0, completed-jobs: u0, total-rating: u0, rating-count: u0, last-updated: u0 }
          (map-get? freelancer-reputation freelancer)
        ))
        (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR-INVALID-STATE))
      )
      (map-set freelancer-reputation freelancer
        {
          total-jobs: (get total-jobs current-rep),
          completed-jobs: (get completed-jobs current-rep),
          total-rating: (+ (get total-rating current-rep) rating),
          rating-count: (+ (get rating-count current-rep) u1),
          last-updated: current-time
        }
      )
      (ok true)
    )
  )
)

(define-private (update-freelancer-stats (freelancer principal) (completed bool))
  (let 
    (
      (current-rep (default-to 
        { total-jobs: u0, completed-jobs: u0, total-rating: u0, rating-count: u0, last-updated: u0 }
        (map-get? freelancer-reputation freelancer)
      ))
      (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR-INVALID-STATE))
    )
    (map-set freelancer-reputation freelancer
      {
        total-jobs: (+ (get total-jobs current-rep) u1),
        completed-jobs: (if completed (+ (get completed-jobs current-rep) u1) (get completed-jobs current-rep)),
        total-rating: (get total-rating current-rep),
        rating-count: (get rating-count current-rep),
        last-updated: current-time
      }
    )
    (ok true)
  )
)

(define-read-only (get-freelancer-reputation (freelancer principal))
  (map-get? freelancer-reputation freelancer)
)

(define-read-only (get-freelancer-completion-rate (freelancer principal))
  (let ((rep (map-get? freelancer-reputation freelancer)))
    (match rep
      rep-data (if (> (get total-jobs rep-data) u0)
                 (some (/ (* (get completed-jobs rep-data) u100) (get total-jobs rep-data)))
                 (some u0))
      none
    )
  )
)

(define-read-only (get-freelancer-average-rating (freelancer principal))
  (let ((rep (map-get? freelancer-reputation freelancer)))
    (match rep
      rep-data (if (> (get rating-count rep-data) u0)
                 (some (/ (get total-rating rep-data) (get rating-count rep-data)))
                 none)
      none
    )
  )
)



(define-map milestones
  uint
  {
    job-id: uint,
    title: (string-ascii 100),
    amount: uint,
    deadline: uint,
    state: uint,
    created-at: uint
  }
)

(define-map job-milestones
  uint
  { milestone-ids: (list 20 uint), total-milestones: uint }
)

(define-public (create-milestone (job-id uint) (title (string-ascii 100)) (amount uint) (deadline uint))
  (let 
    (
      (job-data (unwrap! (map-get? jobs job-id) ERR-INVALID-JOB))
      (milestone-id (+ (var-get milestone-counter) u1))
      (current-milestones (default-to { milestone-ids: (list), total-milestones: u0 } (map-get? job-milestones job-id)))
    )
    (asserts! (is-eq tx-sender (get client job-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state job-data) JOB-STATE-CREATED) ERR-INVALID-STATE)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (< (len (get milestone-ids current-milestones)) u20) ERR-INVALID-STATE)
    (var-set milestone-counter milestone-id)
    (map-set milestones milestone-id
      {
        job-id: job-id,
        title: title,
        amount: amount,
        deadline: deadline,
        state: MILESTONE-STATE-PENDING,
        created-at: (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR-INVALID-STATE)
      }
    )
    (map-set job-milestones job-id
      {
        milestone-ids: (unwrap! (as-max-len? (append (get milestone-ids current-milestones) milestone-id) u20) ERR-INVALID-STATE),
        total-milestones: (+ (get total-milestones current-milestones) u1)
      }
    )
    (ok milestone-id)
  )
)

(define-public (fund-milestone (milestone-id uint))
  (let ((milestone-data (unwrap! (map-get? milestones milestone-id) ERR-INVALID-JOB)))
    (asserts! (is-eq (get state milestone-data) MILESTONE-STATE-PENDING) ERR-INVALID-STATE)
    (let ((job-data (unwrap! (map-get? jobs (get job-id milestone-data)) ERR-INVALID-JOB)))
      (asserts! (is-eq tx-sender (get client job-data)) ERR-UNAUTHORIZED)
      (try! (stx-transfer? (get amount milestone-data) tx-sender (as-contract tx-sender)))
      (map-set milestones milestone-id (merge milestone-data { state: MILESTONE-STATE-FUNDED }))
      (ok true)
    )
  )
)

(define-public (complete-milestone (milestone-id uint))
  (let ((milestone-data (unwrap! (map-get? milestones milestone-id) ERR-INVALID-JOB)))
    (asserts! (is-eq (get state milestone-data) MILESTONE-STATE-FUNDED) ERR-INVALID-STATE)
    (let ((job-data (unwrap! (map-get? jobs (get job-id milestone-data)) ERR-INVALID-JOB)))
      (asserts! (is-eq tx-sender (get freelancer job-data)) ERR-UNAUTHORIZED)
      (map-set milestones milestone-id (merge milestone-data { state: MILESTONE-STATE-COMPLETED }))
      (ok true)
    )
  )
)

(define-public (approve-milestone (milestone-id uint))
  (let ((milestone-data (unwrap! (map-get? milestones milestone-id) ERR-INVALID-JOB)))
    (asserts! (is-eq (get state milestone-data) MILESTONE-STATE-COMPLETED) ERR-INVALID-STATE)
    (let ((job-data (unwrap! (map-get? jobs (get job-id milestone-data)) ERR-INVALID-JOB)))
      (asserts! (is-eq tx-sender (get client job-data)) ERR-UNAUTHORIZED)
      (try! (as-contract (stx-transfer? (get amount milestone-data) tx-sender (get freelancer job-data))))
      (map-set milestones milestone-id (merge milestone-data { state: MILESTONE-STATE-APPROVED }))
      (ok true)
    )
  )
)

(define-read-only (get-milestone (milestone-id uint))
  (map-get? milestones milestone-id)
)

(define-read-only (get-job-milestones (job-id uint))
  (map-get? job-milestones job-id)
)

(define-read-only (get-milestone-counter)
  (var-get milestone-counter)
)

(define-map platform-analytics
  uint
  {
    period-start: uint,
    period-end: uint,
    total-jobs-created: uint,
    total-jobs-completed: uint,
    total-disputes: uint,
    total-volume: uint,
    avg-completion-time: uint,
    active-freelancers: uint,
    active-clients: uint
  }
)

(define-map job-performance-metrics
  uint
  {
    completion-rate: uint,
    avg-duration: uint,
    dispute-rate: uint,
    payment-velocity: uint,
    last-calculated: uint
  }
)

(define-map user-activity-tracker
  principal
  {
    jobs-as-client: uint,
    jobs-as-freelancer: uint,
    total-earnings: uint,
    total-spent: uint,
    last-activity: uint,
    activity-streak: uint
  }
)

(define-public (calculate-platform-metrics (period-blocks uint))
  (let 
    (
      (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR-INVALID-STATE))
      (analytics-id (+ (var-get analytics-counter) u1))
      (period-start (- current-time period-blocks))
    )
    (var-set analytics-counter analytics-id)
    (map-set platform-analytics analytics-id
      {
        period-start: period-start,
        period-end: current-time,
        total-jobs-created: (var-get job-counter),
        total-jobs-completed: (calculate-completed-jobs),
        total-disputes: (var-get dispute-counter),
        total-volume: (calculate-total-volume),
        avg-completion-time: (calculate-avg-completion-time),
        active-freelancers: (calculate-active-users true),
        active-clients: (calculate-active-users false)
      }
    )
    (ok analytics-id)
  )
)

(define-private (calculate-completed-jobs)
  (fold count-completed-job (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) u0)
)

(define-private (count-completed-job (job-id uint) (count uint))
  (let ((job-data (map-get? jobs job-id)))
    (match job-data
      job (if (is-eq (get state job) JOB-STATE-RESOLVED) (+ count u1) count)
      count
    )
  )
)

(define-private (calculate-total-volume)
  (fold sum-job-amounts (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) u0)
)

(define-private (sum-job-amounts (job-id uint) (total uint))
  (let ((job-data (map-get? jobs job-id)))
    (match job-data
      job (+ total (get amount job))
      total
    )
  )
)

(define-private (calculate-avg-completion-time)
  u5040
)

(define-private (calculate-active-users (is-freelancer bool))
  u50
)

(define-public (update-user-activity (user principal) (amount uint) (is-earning bool))
  (let 
    (
      (current-activity (default-to 
        { jobs-as-client: u0, jobs-as-freelancer: u0, total-earnings: u0, total-spent: u0, last-activity: u0, activity-streak: u0 }
        (map-get? user-activity-tracker user)
      ))
      (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR-INVALID-STATE))
    )
    (map-set user-activity-tracker user
      {
        jobs-as-client: (if is-earning (get jobs-as-client current-activity) (+ (get jobs-as-client current-activity) u1)),
        jobs-as-freelancer: (if is-earning (+ (get jobs-as-freelancer current-activity) u1) (get jobs-as-freelancer current-activity)),
        total-earnings: (if is-earning (+ (get total-earnings current-activity) amount) (get total-earnings current-activity)),
        total-spent: (if is-earning (get total-spent current-activity) (+ (get total-spent current-activity) amount)),
        last-activity: current-time,
        activity-streak: (if (< (- current-time (get last-activity current-activity)) u1008) (+ (get activity-streak current-activity) u1) u1)
      }
    )
    (ok true)
  )
)

(define-read-only (get-platform-analytics (analytics-id uint))
  (map-get? platform-analytics analytics-id)
)

(define-read-only (get-user-activity (user principal))
  (map-get? user-activity-tracker user)
)

(define-read-only (get-performance-score (user principal))
  (let ((activity (map-get? user-activity-tracker user)))
    (match activity
      data (if (> (get jobs-as-freelancer data) u0)
             (some (/ (* (get jobs-as-freelancer data) u100) (+ (get jobs-as-freelancer data) (get jobs-as-client data))))
             (some u0))
      none
    )
  )
)

(define-read-only (get-latest-analytics)
  (let ((latest-id (var-get analytics-counter)))
    (if (> latest-id u0)
      (map-get? platform-analytics latest-id)
      none
    )
  )
)

(define-map recurring-jobs
  uint
  {
    client: principal,
    freelancer: principal,
    amount-per-cycle: uint,
    total-cycles: uint,
    completed-cycles: uint,
    interval-blocks: uint,
    state: uint,
    created-at: uint,
    last-payment-at: uint,
    next-payment-due: uint
  }
)

(define-public (create-recurring-job (freelancer principal) (amount-per-cycle uint) (total-cycles uint) (interval-blocks uint))
  (let ((recurring-id (+ (var-get recurring-counter) u1)))
    (asserts! (> amount-per-cycle u0) ERR-INVALID-AMOUNT)
    (asserts! (> total-cycles u0) ERR-RECURRING-INVALID)
    (asserts! (> interval-blocks u0) ERR-RECURRING-INVALID)
    (var-set recurring-counter recurring-id)
    (map-set recurring-jobs recurring-id
      {
        client: tx-sender,
        freelancer: freelancer,
        amount-per-cycle: amount-per-cycle,
        total-cycles: total-cycles,
        completed-cycles: u0,
        interval-blocks: interval-blocks,
        state: RECURRING-STATE-ACTIVE,
        created-at: stacks-block-height,
        last-payment-at: u0,
        next-payment-due: (+ stacks-block-height interval-blocks)
      }
    )
    (ok recurring-id)
  )
)

(define-public (fund-recurring-job (recurring-id uint))
  (let ((recurring-data (unwrap! (map-get? recurring-jobs recurring-id) ERR-RECURRING-INVALID)))
    (asserts! (is-eq tx-sender (get client recurring-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get completed-cycles recurring-data) u0) ERR-INVALID-STATE)
    (try! (stx-transfer? (* (get amount-per-cycle recurring-data) (get total-cycles recurring-data)) tx-sender (as-contract tx-sender)))
    (ok true)
  )
)

(define-public (release-recurring-payment (recurring-id uint))
  (let ((recurring-data (unwrap! (map-get? recurring-jobs recurring-id) ERR-RECURRING-INVALID)))
    (asserts! (is-eq (get state recurring-data) RECURRING-STATE-ACTIVE) ERR-INVALID-STATE)
    (asserts! (>= stacks-block-height (get next-payment-due recurring-data)) ERR-RECURRING-NOT-DUE)
    (asserts! (< (get completed-cycles recurring-data) (get total-cycles recurring-data)) ERR-RECURRING-EXHAUSTED)
    (try! (as-contract (stx-transfer? (get amount-per-cycle recurring-data) tx-sender (get freelancer recurring-data))))
    (map-set recurring-jobs recurring-id (merge recurring-data
      {
        completed-cycles: (+ (get completed-cycles recurring-data) u1),
        last-payment-at: stacks-block-height,
        next-payment-due: (+ stacks-block-height (get interval-blocks recurring-data)),
        state: (if (is-eq (+ (get completed-cycles recurring-data) u1) (get total-cycles recurring-data)) RECURRING-STATE-COMPLETED (get state recurring-data))
      }
    ))
    (ok true)
  )
)

(define-public (cancel-recurring-job (recurring-id uint))
  (let ((recurring-data (unwrap! (map-get? recurring-jobs recurring-id) ERR-RECURRING-INVALID)))
    (asserts! (is-eq tx-sender (get client recurring-data)) ERR-UNAUTHORIZED)
    (asserts! (< (get completed-cycles recurring-data) (get total-cycles recurring-data)) ERR-RECURRING-EXHAUSTED)
    (let ((remaining-cycles (- (get total-cycles recurring-data) (get completed-cycles recurring-data))))
      (try! (as-contract (stx-transfer? (* (get amount-per-cycle recurring-data) remaining-cycles) tx-sender (get client recurring-data))))
      (map-set recurring-jobs recurring-id (merge recurring-data { state: RECURRING-STATE-CANCELLED }))
      (ok true)
    )
  )
)

(define-read-only (get-recurring-job (recurring-id uint))
  (map-get? recurring-jobs recurring-id)
)

(define-read-only (get-recurring-counter)
  (var-get recurring-counter)
)


(define-map job-bonus-pools
  uint
  {
    total-amount: uint,
    tier-1-threshold: uint,
    tier-1-payout: uint,
    tier-2-threshold: uint,
    tier-2-payout: uint,
    tier-3-threshold: uint,
    tier-3-payout: uint,
    state: uint,
    created-at: uint
  }
)

(define-map bonus-claims
  uint
  {
    claimed-by: principal,
    amount-claimed: uint,
    completion-time: uint,
    claimed-at: uint
  }
)

(define-public (create-bonus-pool 
  (job-id uint) 
  (total-amount uint)
  (tier-1-hours uint) 
  (tier-1-payout uint)
  (tier-2-hours uint) 
  (tier-2-payout uint)
  (tier-3-hours uint) 
  (tier-3-payout uint))
  (let 
    (
      (job-data (unwrap! (map-get? jobs job-id) ERR-INVALID-JOB))
      (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR-INVALID-STATE))
    )
    (asserts! (is-eq tx-sender (get client job-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state job-data) JOB-STATE-CREATED) ERR-INVALID-STATE)
    (asserts! (is-none (map-get? job-bonus-pools job-id)) ERR-BONUS-EXISTS)
    (asserts! (>= total-amount (+ tier-1-payout (+ tier-2-payout tier-3-payout))) ERR-BONUS-INVALID)
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
    (map-set job-bonus-pools job-id
      {
        total-amount: total-amount,
        tier-1-threshold: tier-1-hours,
        tier-1-payout: tier-1-payout,
        tier-2-threshold: tier-2-hours,
        tier-2-payout: tier-2-payout,
        tier-3-threshold: tier-3-hours,
        tier-3-payout: tier-3-payout,
        state: BONUS-STATE-LOCKED,
        created-at: current-time
      }
    )
    (ok true)
  )
)

(define-public (claim-early-bonus (job-id uint))
  (let 
    (
      (job-data (unwrap! (map-get? jobs job-id) ERR-INVALID-JOB))
      (bonus-pool (unwrap! (map-get? job-bonus-pools job-id) ERR-BONUS-INVALID))
      (completion-time (- (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR-INVALID-STATE) (get created-at job-data)))
      (bonus-amount (unwrap! (get-applicable-bonus-tier job-id completion-time) ERR-BONUS-NOT-ELIGIBLE))
    )
    (asserts! (is-eq tx-sender (get freelancer job-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state job-data) JOB-STATE-RESOLVED) ERR-INVALID-STATE)
    (asserts! (is-eq (get state bonus-pool) BONUS-STATE-LOCKED) ERR-INVALID-STATE)
    (asserts! (is-none (map-get? bonus-claims job-id)) ERR-BONUS-ALREADY-CLAIMED)
    (try! (as-contract (stx-transfer? bonus-amount tx-sender (get freelancer job-data))))
    (map-set bonus-claims job-id
      {
        claimed-by: tx-sender,
        amount-claimed: bonus-amount,
        completion-time: completion-time,
        claimed-at: (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) ERR-INVALID-STATE)
      }
    )
    (map-set job-bonus-pools job-id (merge bonus-pool { state: BONUS-STATE-CLAIMED }))
    (ok bonus-amount)
  )
)

(define-read-only (get-applicable-bonus-tier (job-id uint) (completion-time-seconds uint))
  (let ((bonus-pool (unwrap! (map-get? job-bonus-pools job-id) ERR-BONUS-INVALID)))
    (if (<= completion-time-seconds (get tier-1-threshold bonus-pool))
      (ok (get tier-1-payout bonus-pool))
      (if (<= completion-time-seconds (get tier-2-threshold bonus-pool))
        (ok (get tier-2-payout bonus-pool))
        (if (<= completion-time-seconds (get tier-3-threshold bonus-pool))
          (ok (get tier-3-payout bonus-pool))
          ERR-BONUS-NOT-ELIGIBLE
        )
      )
    )
  )
)

(define-public (refund-bonus-pool (job-id uint))
  (let 
    (
      (job-data (unwrap! (map-get? jobs job-id) ERR-INVALID-JOB))
      (bonus-pool (unwrap! (map-get? job-bonus-pools job-id) ERR-BONUS-INVALID))
    )
    (asserts! (is-eq tx-sender (get client job-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state bonus-pool) BONUS-STATE-LOCKED) ERR-INVALID-STATE)
    (asserts! (or (is-eq (get state job-data) JOB-STATE-CANCELLED) (is-eq (get state job-data) JOB-STATE-RESOLVED)) ERR-INVALID-STATE)
    (asserts! (is-none (map-get? bonus-claims job-id)) ERR-BONUS-ALREADY-CLAIMED)
    (try! (as-contract (stx-transfer? (get total-amount bonus-pool) tx-sender (get client job-data))))
    (map-set job-bonus-pools job-id (merge bonus-pool { state: BONUS-STATE-REFUNDED }))
    (ok true)
  )
)

(define-read-only (get-bonus-pool (job-id uint))
  (map-get? job-bonus-pools job-id)
)

(define-read-only (get-bonus-claim (job-id uint))
  (map-get? bonus-claims job-id)
)