# Application source (Online Boutique)

Add the microservices here — typically by **forking** or **subtree** of [GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo).

Expected service folders (see `docs/architecture-design.md` §3):

- `frontend`, `cartservice`, `productcatalogservice`, `currencyservice`, `paymentservice`, `shippingservice`, `emailservice`, `checkoutservice`, `recommendationservice`, `adservice`, `loadgenerator`, `redis-cart`

**Example — git subtree (run from repo root):**

```bash
git remote add microservices-demo https://github.com/GoogleCloudPlatform/microservices-demo.git
git fetch microservices-demo
git subtree add --prefix=apps/microservices-demo microservices-demo main --squash
```

Then either keep paths under `apps/microservices-demo/src/...` in pipelines or reorganize into `apps/<service>/`.
