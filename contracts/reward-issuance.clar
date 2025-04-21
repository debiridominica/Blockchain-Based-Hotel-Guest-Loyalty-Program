;; Reward Issuance Contract
;; Manages points and redemption opportunities

(define-data-var admin principal tx-sender)

;; Map to store point balances
(define-map point-balances principal uint)

;; Map to store reward options
(define-map reward-options
  uint
  {
    name: (string-ascii 100),
    description: (string-ascii 255),
    points-required: uint,
    available: bool
  }
)

;; Map to store redemption history
(define-map redemption-history
  { guest-id: principal, redemption-id: uint }
  {
    reward-id: uint,
    points-spent: uint,
    redemption-date: uint,
    status: (string-ascii 20)
  }
)

;; Map to track the number of redemptions per guest
(define-map guest-redemption-count principal uint)

;; Counter for reward IDs
(define-data-var next-reward-id uint u1)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Add points to a guest's balance (called by stay-tracking contract)
(define-public (add-points (guest-id principal) (points uint))
  (let ((current-balance (default-to u0 (map-get? point-balances guest-id))))
    (begin
      ;; In production, would verify caller is the stay-tracking contract
      ;; For simplicity, allowing any caller
      (ok (map-set point-balances guest-id (+ current-balance points)))
    )
  )
)

;; Get point balance
(define-read-only (get-point-balance (guest-id principal))
  (default-to u0 (map-get? point-balances guest-id))
)

;; Add a new reward option (admin only)
(define-public (add-reward-option (name (string-ascii 100)) (description (string-ascii 255)) (points-required uint))
  (let ((reward-id (var-get next-reward-id)))
    (begin
      (asserts! (is-admin) (err u1))
      (map-set reward-options
        reward-id
        {
          name: name,
          description: description,
          points-required: points-required,
          available: true
        }
      )
      (var-set next-reward-id (+ reward-id u1))
      (ok reward-id)
    )
  )
)

;; Update reward availability (admin only)
(define-public (update-reward-availability (reward-id uint) (available bool))
  (let ((reward (unwrap! (map-get? reward-options reward-id) (err u2))))
    (begin
      (asserts! (is-admin) (err u1))
      (ok (map-set reward-options
        reward-id
        (merge reward {
          available: available
        })
      ))
    )
  )
)

;; Get reward details
(define-read-only (get-reward-details (reward-id uint))
  (map-get? reward-options reward-id)
)

;; Get the next redemption ID for a guest
(define-private (get-next-redemption-id (guest-id principal))
  (default-to u0 (map-get? guest-redemption-count guest-id))
)

;; Redeem points for a reward
(define-public (redeem-reward (reward-id uint))
  (let (
    (reward (unwrap! (map-get? reward-options reward-id) (err u2)))
    (points-required (get points-required reward))
    (current-balance (default-to u0 (map-get? point-balances tx-sender)))
    (redemption-id (+ u1 (get-next-redemption-id tx-sender)))
  )
    (begin
      ;; Check reward is available
      (asserts! (get available reward) (err u3))

      ;; Check guest has enough points
      (asserts! (>= current-balance points-required) (err u4))

      ;; Deduct points
      (map-set point-balances tx-sender (- current-balance points-required))

      ;; Record redemption
      (map-set redemption-history
        { guest-id: tx-sender, redemption-id: redemption-id }
        {
          reward-id: reward-id,
          points-spent: points-required,
          redemption-date: block-height,
          status: "redeemed"
        }
      )

      ;; Update the guest's redemption count
      (map-set guest-redemption-count tx-sender redemption-id)

      (ok redemption-id)
    )
  )
)

;; Get redemption details
(define-read-only (get-redemption-details (guest-id principal) (redemption-id uint))
  (map-get? redemption-history { guest-id: guest-id, redemption-id: redemption-id })
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err u5))
    (ok (var-set admin new-admin))
  )
)
