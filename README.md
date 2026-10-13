# yente

`yente` is an open source data match-making API. The service provides several HTTP endpoints to search, retrieve or match [FollowTheMoney entities](https://www.opensanctions.org/docs/entities/), including people, companies or vessels that are subject to international sanctions.

The yente API is built to provide access to [OpenSanctions data](https://www.opensanctions.org/datasets/), and can also be used to search and match other data, such as [company registries](https://www.opensanctions.org/datasets/kyb/) or [custom watchlists](https://www.opensanctions.org/docs/yente/datasets/).

While `yente` is the open source core code base for the [OpenSanctions API](https://www.opensanctions.org/api/), it can also be run [on-premises as a KYC appliance](https://www.opensanctions.org/docs/self-hosted/) so that no customer data leaves your infrastructure.

* [yente documentation](https://www.opensanctions.org/docs/yente/) - install, configure and use the service.

## Local screening setup

This checkout runs Yente on your computer at `http://127.0.0.1:8000`. Yente itself is the API: there is no separate Yente API server to sign up for. It searches the individual datasets in OpenSanctions' full `sanctions` collection, including the EU Financial Sanctions (`eu_fsf`), UN Security Council (`un_sc_sanctions`), Polish MSWiA (`pl_mswia_sanctions`), and other sanctions datasets. The 93 source datasets are indexed one at a time.

### Start and stop

Open a terminal in this repository folder, then start the app:

```bash
docker compose up -d --build
```

Wait until the `app` and `index` services show `healthy`:

```bash
docker compose ps
curl http://127.0.0.1:8000/readyz
```

`readyz` returning `{"status":"ok"}` means the search index is ready. You can also open the interactive API documentation at <http://127.0.0.1:8000/> or see the configured datasets at <http://127.0.0.1:8000/catalog>.

Stop the app while keeping its downloaded/indexed data:

```bash
docker compose stop
```

Start it again with `docker compose start` (or `docker compose up -d`). `docker compose down` also stops and removes the containers but keeps the named search-data volume. **Do not add `-v` to `docker compose down`** unless you intend to erase the indexes and start over.

### Check a name or address

Send a `POST` request to Yente's `/match/sanctions` endpoint. Replace the example name and details with the person you want to check. Include any reliable details you have; address, birth date, country, and phone can help distinguish people with similar names.

```bash
curl -X POST http://127.0.0.1:8000/match/sanctions \
  -H 'Content-Type: application/json' \
  -d '{"queries":{"check-1":{"schema":"Person","properties":{"name":["Jane Doe"],"birthDate":["1980-01-01"],"address":["10 Example Street, Berlin, Germany"],"country":["Germany"]}}}}'
```

That request searches **all configured sanctions lists**. To search only the EU, UN, and Polish lists first, use the same request with these filters:

```bash
curl -X POST 'http://127.0.0.1:8000/match/sanctions?include_dataset=eu_fsf&include_dataset=un_sc_sanctions&include_dataset=pl_mswia_sanctions' \
  -H 'Content-Type: application/json' \
  -d '{"queries":{"check-1":{"schema":"Person","properties":{"name":["Jane Doe"],"birthDate":["1980-01-01"],"address":["10 Example Street, Berlin, Germany"],"country":["Germany"]}}}}'
```

If the first response has no results, retry against `/match/sanctions` without the `include_dataset` filters to search all configured sanctions lists. In the JSON response, look under `responses` → `check-1` → `results`. An empty `results` array means Yente returned no candidates. For each candidate, check its `caption`, `datasets`, and other properties to see which list it came from and whether the details fit. Yente uses name matching that can find spelling variations, but its results are candidates for human review, not an automatic legal determination; no result is not proof that a person is absent from every list.

For a company or other organization, use `"schema":"Company"` and provide its name and known address details. The API listens only on localhost in this configuration, so it is available on this computer and is not exposed to your network.

### Data updates

The app checks OpenSanctions for newer data when it starts and then hourly. If all indexed versions are current, starting the app only checks the catalog and leaves the existing indexes in place. If a dataset has a newer version (or has no index yet), Yente downloads and indexes the needed data one dataset at a time. This uses the local Elasticsearch search index; it does not use PostgreSQL.

The civic data feed is intended for non-commercial use. Commercial use requires an OpenSanctions data license and delivery token.

## Development

`yente` is implemented in asynchronous, typed Python using the FastAPI framework. We're happy to see any bug fixes, improvements or extensions from the community. Use Python 3.14 and a project virtual environment for local development:

```bash
git clone https://github.com/opensanctions/yente.git
cd yente
# Install runtime, development and documentation dependencies in .venv
make setup-python
# Install pre-commit hooks
.venv/bin/prek install
```

`make test`, `make typecheck`, and `make docs` use `.venv` automatically. Python requirements stay in `pyproject.toml`; Docker creates its own `/opt/venv` using Python 3.14.\n\nOn Ubuntu, install build prerequisites with `sudo apt-get install python3-venv build-essential pkg-config libicu-dev`.\n\nThis will install a broad range of dependencies, including `numpy`, `scikit-learn` and `pyicu`, which are binary packages that may require a local build environment. For `pyicu` in particular, refer to the [package documentation](https://pypi.org/project/PyICU/).

### Running the server

Once you've set the ``YENTE_INDEX_URL`` environment variable to point to a running instance of ElasticSearch or OpenSearch, you can run the web server like this:

```bash
.venv/bin/yente serve
```


### Releasing

    .venv/bin/bump2version --verbose minor # or patch
    git push && git push --tags

### Debugging using OpenTelemetry Tracing

You'll need a local piece of software to receive and display traces. [Jaeger]() is widely used and has an easy-to-use Docker image. Paste the command to start the all-in-one container from [the Jaeger documentation](https://www.jaegertracing.io/docs/latest/getting-started/) and find the web interface at http://localhost:16686.

Then, just run yente like this:

```sh
.venv/bin/opentelemetry-instrument --exporter_otlp_traces_endpoint="http://localhost:4317" .venv/bin/yente serve
```

## License and Support

``yente`` is licensed according to the MIT license terms documented in ``LICENSE``. Using the service in a commercial context may require a [data license for OpenSanctions data](https://www.opensanctions.org/licensing/).
