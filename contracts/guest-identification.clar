;; Guest Identification Contract
;; Manages secure traveler profiles

(define-data-var admin principal tx-sender)

;; Map to store guest profiles
(define-map guest-profiles
  principal
  {
    name: (string-ascii 100),
    email-hash: (buff 32),
    membership-tier: (string-ascii 20),
    registration-date: uint,
    total-stays: uint
  }
)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Register a new guest
(define-public (register-guest (name (string-ascii 100)) (email-hash (buff 32)))
  (begin
    (asserts! (is-none (map-get? guest-profiles tx-sender)) (err u1))
    (ok (map-set guest-profiles
      tx-sender
      {
        name: name,
        email-hash: email-hash,
        membership-tier: "standard",
        registration-date: block-height,
        total-stays: u0
      }
    ))
  )
)

;; Update guest profile
(define-public (update-profile (name (string-ascii 100)) (email-hash (buff 32)))
  (let ((profile (unwrap! (map-get? guest-profiles tx-sender) (err u2))))
    (ok (map-set guest-profiles
      tx-sender
      (merge profile {
        name: name,
        email-hash: email-hash
      })
    ))
  )
)

;; Update membership tier (admin only)
(define-public (update-membership-tier (guest-id principal) (tier (string-ascii 20)))
  (let ((profile (unwrap! (map-get? guest-profiles guest-id) (err u2))))
    (begin
      (asserts! (is-admin) (err u3))
      (ok (map-set guest-profiles
        guest-id
        (merge profile {
          membership-tier: tier
        })
      ))
    )
  )
)

;; Get guest profile
(define-read-only (get-guest-profile (guest-id principal))
  (map-get? guest-profiles guest-id)
)

;; Check if guest exists
(define-read-only (is-registered-guest (guest-id principal))
  (is-some (map-get? guest-profiles guest-id))
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err u3))
    (ok (var-set admin new-admin))
  )
)
