(ns notes.core
  (:require [muuntaja.core :as m]
            [next.jdbc :as jdbc]
            [next.jdbc.result-set :as rs]
            [reitit.ring :as ring]
            [reitit.ring.middleware.muuntaja :as muuntaja]
            [ring.adapter.jetty :refer [run-jetty]])
  (:gen-class))

(defn env [k default] (or (System/getenv k) default))

(def db-spec
  {:dbtype "postgresql"
   :host (env "DB_HOST" "localhost")
   :port (parse-long (env "DB_PORT" "5432"))
   :dbname (env "DB_NAME" "notes")
   :user (env "DB_USER" "notes")
   :password (env "DB_PASSWORD" "notes")})

(def jdbc-opts {:builder-fn rs/as-unqualified-lower-maps})

(defn migrate! [ds]
  (jdbc/execute! ds ["CREATE TABLE IF NOT EXISTS notes (
                        id SERIAL PRIMARY KEY,
                        body TEXT NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT now())"]))

(defn ready [ds]
  (try
    (jdbc/execute! ds ["SELECT 1"])
    {:status 200 :body {:status "ready"}}
    (catch Exception e
      {:status 503 :body {:status "db unavailable" :error (.getMessage e)}})))

(defn list-notes [ds]
  {:status 200 :body (jdbc/execute! ds ["SELECT * FROM notes ORDER BY id"] jdbc-opts)})

(defn create-note [ds {{:keys [body]} :body-params}]
  (if (seq body)
    {:status 201
     :body (jdbc/execute-one! ds ["INSERT INTO notes (body) VALUES (?) RETURNING *" body] jdbc-opts)}
    {:status 400 :body {:error "body is required"}}))

(defn app [ds]
  (ring/ring-handler
   (ring/router
    [["/health" {:get (fn [_] {:status 200 :body {:status "ok" :version "2.0"}})}]
     ["/ready" {:get (fn [_] (ready ds))}]
     ["/notes" {:get (fn [_] (list-notes ds))
                :post (fn [req] (create-note ds req))}]]
    {:data {:muuntaja m/instance
            :middleware [muuntaja/format-middleware]}})
   (ring/create-default-handler)))

(defn -main [& _]
  (let [ds (jdbc/get-datasource db-spec)
        port (parse-long (env "PORT" "8080"))]
    (migrate! ds)
    (println "notes service listening on" port)
    (run-jetty (app ds) {:port port :join? true})))