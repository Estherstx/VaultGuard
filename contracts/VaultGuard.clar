;; VaultGuard - Time-locked Savings Vault Contract
;; A secure vault system for time-locked STX deposits

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-vault-locked (err u103))
(define-constant err-insufficient-balance (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-invalid-duration (err u106))
(define-constant err-overflow (err u107))
(define-constant err-invalid-vault-id (err u108))
(define-constant max-lock-duration u525600) ;; ~1 year in blocks
(define-constant min-lock-duration u1) ;; minimum 1 block
(define-constant max-vault-id u1000000) ;; reasonable upper limit for vault IDs

;; Data Variables
(define-data-var total-vaults uint u0)
(define-data-var contract-balance uint u0)

;; Data Maps
(define-map vaults
  { vault-id: uint }
  {
    owner: principal,
    amount: uint,
    unlock-height: uint,
    created-at: uint,
    is-active: bool
  }
)

(define-map user-vault-count
  { user: principal }
  { count: uint }
)

;; Private Functions
(define-private (is-valid-vault-id (vault-id uint))
  (and (> vault-id u0) (<= vault-id max-vault-id))
)

(define-private (get-next-vault-id)
  (begin
    (var-set total-vaults (+ (var-get total-vaults) u1))
    (var-get total-vaults)
  )
)

(define-private (increment-user-vault-count (user principal))
  (let ((current-count (default-to u0 (get count (map-get? user-vault-count { user: user })))))
    (map-set user-vault-count { user: user } { count: (+ current-count u1) })
  )
)

;; Read-only Functions
(define-read-only (get-vault (vault-id uint))
  (if (is-valid-vault-id vault-id)
    (map-get? vaults { vault-id: vault-id })
    none
  )
)

(define-read-only (get-total-vaults)
  (var-get total-vaults)
)

(define-read-only (get-user-vault-count (user principal))
  (default-to u0 (get count (map-get? user-vault-count { user: user })))
)

(define-read-only (get-contract-balance)
  (var-get contract-balance)
)

(define-read-only (is-vault-unlocked (vault-id uint))
  (begin
    (asserts! (is-valid-vault-id vault-id) false)
    (match (map-get? vaults { vault-id: vault-id })
      vault-data (>= stacks-block-height (get unlock-height vault-data))
      false
    )
  )
)

;; Public Functions
(define-public (create-vault (amount uint) (lock-duration uint))
  (let (
    (vault-id (get-next-vault-id))
    (current-balance (stx-get-balance tx-sender))
    (current-block stacks-block-height)
  )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= lock-duration min-lock-duration) err-invalid-duration)
    (asserts! (<= lock-duration max-lock-duration) err-invalid-duration)
    (asserts! (>= current-balance amount) err-insufficient-balance)
    
    ;; Check for overflow when calculating unlock height
    (asserts! (<= lock-duration (- u340282366920938463463374607431768211455 current-block)) err-overflow)
    
    (let ((unlock-height (+ current-block lock-duration)))
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      
      (map-set vaults
        { vault-id: vault-id }
        {
          owner: tx-sender,
          amount: amount,
          unlock-height: unlock-height,
          created-at: current-block,
          is-active: true
        }
      )
      
      (increment-user-vault-count tx-sender)
      (var-set contract-balance (+ (var-get contract-balance) amount))
      
      (ok vault-id)
    )
  )
)

(define-public (withdraw-from-vault (vault-id uint))
  (begin
    (asserts! (is-valid-vault-id vault-id) err-invalid-vault-id)
    (let (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) err-not-found))
      (vault-amount (get amount vault-data))
      (vault-owner (get owner vault-data))
      (current-block stacks-block-height)
    )
      (asserts! (is-eq tx-sender vault-owner) err-unauthorized)
      (asserts! (get is-active vault-data) err-not-found)
      (asserts! (>= current-block (get unlock-height vault-data)) err-vault-locked)
      (asserts! (> vault-amount u0) err-invalid-amount)
      
      (try! (as-contract (stx-transfer? vault-amount tx-sender vault-owner)))
      
      (map-set vaults
        { vault-id: vault-id }
        (merge vault-data { is-active: false })
      )
      
      (var-set contract-balance (- (var-get contract-balance) vault-amount))
      
      (ok vault-amount)
    )
  )
)

(define-public (emergency-withdraw (vault-id uint))
  (begin
    (asserts! (is-valid-vault-id vault-id) err-invalid-vault-id)
    (let (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) err-not-found))
      (vault-amount (get amount vault-data))
      (vault-owner (get owner vault-data))
      (current-block stacks-block-height)
    )
      (asserts! (is-eq tx-sender vault-owner) err-unauthorized)
      (asserts! (get is-active vault-data) err-not-found)
      (asserts! (< current-block (get unlock-height vault-data)) err-vault-locked)
      (asserts! (> vault-amount u0) err-invalid-amount)
      
      (let (
        (penalty-amount (/ vault-amount u10)) ;; 10% penalty
        (withdrawal-amount (- vault-amount penalty-amount))
      )
        (asserts! (> withdrawal-amount u0) err-invalid-amount)
        
        (try! (as-contract (stx-transfer? withdrawal-amount tx-sender vault-owner)))
        
        (map-set vaults
          { vault-id: vault-id }
          (merge vault-data { is-active: false })
        )
        
        (var-set contract-balance (- (var-get contract-balance) vault-amount))
        
        (ok withdrawal-amount)
      )
    )
  )
)