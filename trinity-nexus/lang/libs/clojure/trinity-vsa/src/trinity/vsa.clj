(ns trinity.vsa
  "Trinity VSA - Vector Symbolic Architecture with balanced ternary arithmetic")

(defn zeros [dim]
  (vec (repeat dim 0)))

(defn random-vec [dim seed]
  (let [rng (java.util.Random. seed)]
    (vec (repeatedly dim #(- (.nextInt rng 3) 1)))))

(defn bind [a b]
  {:pre [(= (count a) (count b))]}
  (mapv * a b))

(defn unbind [a b]
  (bind a b))

(defn bundle [vectors]
  {:pre [(seq vectors)]}
  (let [dim (count (first vectors))]
    (vec (for [i (range dim)]
           (let [s (reduce + (map #(nth % i) vectors))]
             (cond (pos? s) 1 (neg? s) -1 :else 0))))))

(defn permute [v shift]
  (let [dim (count v)]
    (vec (for [i (range dim)]
           (nth v (mod (- i shift) dim))))))

(defn dot [a b]
  {:pre [(= (count a) (count b))]}
  (reduce + (map * a b)))

(defn similarity [a b]
  (let [d (double (dot a b))
        norm-a (Math/sqrt (double (dot a a)))
        norm-b (Math/sqrt (double (dot b b)))]
    (if (or (zero? norm-a) (zero? norm-b))
      0.0
      (/ d (* norm-a norm-b)))))

(defn hamming-distance [a b]
  {:pre [(= (count a) (count b))]}
  (count (filter true? (map not= a b))))
