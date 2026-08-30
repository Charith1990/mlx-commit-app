//
//  SampleDiffs.swift
//  mlx-fuse-model-test
//
//  Five real diffs to try the model on. They are copied from the samples/
//  folder in the training project, which is the same set used to score the
//  model before and after training.
//
//  They are written here as plain text instead of files in the app bundle.
//  Fewer moving parts, and you can read them without leaving Xcode.
//

import Foundation

struct SampleDiff: Identifiable {
    let id: String
    let title: String
    let language: String
    let expected: String
    let diff: String
}

let sampleDiffs: [SampleDiff] = [

    // The one that matters most. Part 2 could never get this right: the base
    // model calls a cache a new feature. Nothing new became possible here, the
    // same function returns the same answers with less work, so it is perf.
    SampleDiff(
        id: "perf-cache",
        title: "Cache exchange rates",
        language: "JavaScript",
        expected: "perf",
        diff: """
            diff --git a/src/services/currency.js b/src/services/currency.js
            index 2b3c4d5..5e6f7a8 100644
            --- a/src/services/currency.js
            +++ b/src/services/currency.js
            @@ -1,7 +1,13 @@
            +const cache = new Map();
            +
             async function getRate(from, to) {
            +  const key = `${from}:${to}`;
            +  if (cache.has(key)) return cache.get(key);
            +
               const rate = await api.fetchRate(from, to);
            +  cache.set(key, rate);
               return rate;
             }
            """
    ),

    // The code visibly moves around, so the base model called it a feature.
    // The old code kept collecting after the view was gone. That is a bug.
    SampleDiff(
        id: "fix-lifecycle",
        title: "Collect only while started",
        language: "Kotlin",
        expected: "fix",
        diff: """
            diff --git a/app/src/main/java/com/acme/feed/FeedFragment.kt b/app/src/main/java/com/acme/feed/FeedFragment.kt
            index 5f6a7b8..9c0d1e2 100644
            --- a/app/src/main/java/com/acme/feed/FeedFragment.kt
            +++ b/app/src/main/java/com/acme/feed/FeedFragment.kt
            @@ -22,9 +22,11 @@ class FeedFragment : Fragment() {
                 override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
                     super.onViewCreated(view, savedInstanceState)
            -        lifecycleScope.launch {
            -            viewModel.items.collect { adapter.submitList(it) }
            -        }
            +        viewLifecycleOwner.lifecycleScope.launch {
            +            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
            +                viewModel.items.collect { adapter.submitList(it) }
            +            }
            +        }
                 }
             }
            """
    ),

    // Watch the scope here. The base model always wrote docs(README) in
    // capitals because that is the filename. No prompt rule ever fixed it.
    SampleDiff(
        id: "docs-readme",
        title: "Add requirements to the README",
        language: "Markdown",
        expected: "docs",
        diff: """
            diff --git a/README.md b/README.md
            index 3c4d5e6..6f7a8b9 100644
            --- a/README.md
            +++ b/README.md
            @@ -12,6 +12,13 @@ A local commit-message generator.

             ## Getting started

            +### Requirements
            +
            +- macOS on Apple silicon
            +- Python 3.12 or newer
            +
            +Install the dependencies with `pip install -r requirements.txt`, then run the
            +model download script once before first use.
            +
             ## Usage
            """
    ),

    // A straightforward new endpoint. The base model already got this one
    // right, so it is here to keep the demo honest.
    SampleDiff(
        id: "feat-endpoint",
        title: "Add get order by id",
        language: "Python",
        expected: "feat",
        diff: """
            diff --git a/app/api/routes/orders.py b/app/api/routes/orders.py
            index 1122aa0..33bb112 100644
            --- a/app/api/routes/orders.py
            +++ b/app/api/routes/orders.py
            @@ -10,6 +10,15 @@ router = APIRouter(prefix="/orders", tags=["orders"])
             async def list_orders() -> list[Order]:
                 return await store.all_orders()

            +
            +@router.get("/{order_id}")
            +async def get_order(order_id: int) -> Order:
            +    order = await store.find_order(order_id)
            +    if order is None:
            +        raise HTTPException(status_code=404, detail="Order not found")
            +    return order
            """
    ),

    // Only tests were added. A new file full of + lines is the shape a model
    // is most likely to call a feature.
    SampleDiff(
        id: "test-pricing",
        title: "Add average price tests",
        language: "Python",
        expected: "test",
        diff: """
            diff --git a/tests/test_pricing.py b/tests/test_pricing.py
            new file mode 100644
            index 0000000..a1b2c3d
            --- /dev/null
            +++ b/tests/test_pricing.py
            @@ -0,0 +1,9 @@
            +from app.services.pricing import average_price
            +
            +
            +def test_average_price_of_values():
            +    assert average_price([10.0, 20.0]) == 15.0
            +
            +
            +def test_average_price_of_empty_list():
            +    assert average_price([]) == 0.0
            """
    ),
]
