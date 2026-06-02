import json

filepath = r"d:\Project\grafana\provisioning\dashboards\json\fastapi.json"

with open(filepath, "r", encoding="utf-8") as f:
    dashboard = json.load(f)

# Update Datasource UIDs to match 'Prometheus' and 'Loki'
def fix_datasource(obj):
    if isinstance(obj, dict):
        if obj.get("type") == "prometheus" and obj.get("uid") == "prometheus":
            obj["uid"] = "Prometheus"
        for k, v in obj.items():
            fix_datasource(v)
    elif isinstance(obj, list):
        for item in obj:
            fix_datasource(item)

fix_datasource(dashboard)

# Fix template variables (app_name -> job)
for var in dashboard.get("templating", {}).get("list", []):
    if var.get("name") == "app_name":
        var["definition"] = "label_values(up{job=\"fastapi-app\"}, job)"
        var["query"] = {
            "query": "label_values(up{job=\"fastapi-app\"}, job)",
            "refId": "StandardVariableQuery"
        }
        var["name"] = "app_name"
        var["label"] = "Job Name"

# Replace queries to match actual metrics
for panel in dashboard.get("panels", []):
    # Fix targets
    for target in panel.get("targets", []):
        expr = target.get("expr", "")
        if expr:
            # Replace metric names
            expr = expr.replace("fastapi_requests_total", "http_requests_total")
            expr = expr.replace("fastapi_responses_total", "http_requests_total")
            expr = expr.replace("fastapi_requests_duration_seconds", "http_request_duration_seconds")
            expr = expr.replace("fastapi_exceptions_total", "http_requests_total{status=\"5xx\"}")
            expr = expr.replace("fastapi_requests_in_progress", "http_requests_created")
            
            # Replace labels
            expr = expr.replace("app_name=\"$app_name\"", "job=\"$app_name\"")
            expr = expr.replace("status_code=~\"2.*\"", "status=\"2xx\"")
            expr = expr.replace("status_code=~\"5.*\"", "status=\"5xx\"")
            
            # If path label is used in prometheus-fastapi-instrumentator, it is called 'handler'
            expr = expr.replace("path!=\"/metrics\"", "handler!=\"/metrics\"")
            expr = expr.replace("by(path, le)", "by(handler, le)")
            expr = expr.replace("{{path}}", "{{handler}}")
            expr = expr.replace("{{method}} {{path}}", "{{method}} {{handler}}")
            
            target["expr"] = expr

with open(filepath, "w", encoding="utf-8") as f:
    json.dump(dashboard, f, indent=2)

print("Dashboard successfully rewritten to match project metrics!")
