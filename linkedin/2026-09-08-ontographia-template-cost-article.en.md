# The Graph AI Dilemma: Let LLMs Write Cypher or Suffer Template Maintenance Hell? (Ontographia Part 1)

![The Graph AI Dilemma: Navigating the trade-offs between stochastic LLM generation and deterministic graph execution](../images/ontographia-part1-cover.jpg)

> **Series Overview: The Ontographia Trilogy**
> 
> When querying graph databases (such as Neo4j) with natural language, enterprise teams repeatedly face a difficult dilemma: **Do you let the LLM generate Cypher queries directly, or do you restrict the system to a rigid catalog of handcrafted query templates?**
> 
> This three-part series dissects the architectural limitations of today's dominant compromise—**Agent Skills + Template Selection (the Hybrid approach)**. Drawing on recent research shared by the Neo4j engineering community, we propose and validate a new paradigm: **confine the LLM strictly to extracting structured intent (Intent JSON), while compiling Cypher deterministically through an ontology-constrained Abstract Syntax Tree (AST) pipeline** ([Ontographia](https://github.com/edgesentry/ontographia)).
> 
> * **Part 1: The Graph AI Dilemma: Let LLMs Write Cypher or Suffer Template Maintenance Hell?** *(This article)*  
>   *Focus: Production bottlenecks, state-of-the-art research review, and the Intent-first hypothesis*
> * **Part 2: Intent-First Design and Implementation: Deterministic Cypher Assembly** *(Upcoming)*  
>   *Focus: Separation of Core and App layers, AST compiler internals, and execution loop*
> * **Part 3: Empirical Validation and Roadmap: Large-Scale Ontology Evaluation and External Validity** *(Upcoming)*  
>   *Focus: Quantitative stress testing (token reduction, silent error mitigation) & public DB benchmarks*
> 
> * Project Documentation: [edgesentry.github.io/ontographia](https://edgesentry.github.io/ontographia/)  
> * Open Source Repository: [github.com/edgesentry/ontographia](https://github.com/edgesentry/ontographia)

---

## Executive Summary

Enterprise knowledge graphs—spanning manufacturing Bills of Materials (BOM), multi-tier supply chain traceability, quality assurance, and asset management—are built around relationships. As enterprise generative AI matures, business demand for querying these deeply interconnected graph structures using natural language has surged.

However, deploying **raw Text-to-Cypher** directly to production remains fraught with peril. Syntax errors, schema hallucinations (inventing non-existent node labels, edge types, or property names), prompt injection vulnerabilities, and runaway Cartesian products that hang mission-critical databases make unguarded LLM generation untenable in governed environments.

To avoid these risks, engineering teams frequently adopt a **hybrid pattern**: they craft pre-approved, parameterized Cypher templates, register them as **Agent Skills (Tool Calling / Function Calling)**, and prompt the LLM to classify user queries into the right template while extracting parameters.

At first glance, this looks like the ideal compromise between LLM adaptability and enterprise safety. Yet over months of real-world operation, the operational bottleneck quietly shifts: **from "LLM hallucination risk" to an unsustainable explosion of human template authoring, maintenance, and regression testing.**

In this article (Part 1), we break down why the current hybrid architecture inevitably hits a maintenance wall, analyze recent research from the Neo4j and NLP communities, and introduce a new architectural paradigm—**the Intent-First Hypothesis**—designed to scale natural language graph interfaces without trading safety for operational paralysis.

---

## 1. The Three Approaches Encountered in Production

Practitioners trying to translate natural language into graph queries typically choose among three architectural patterns along a spectrum of control:

* **1. 100% Non-Deterministic (Raw Text-to-Cypher):** High agility, zero safety guarantees.
* **2. The Current Hybrid (Agent Skills + Templates):** High safety, fragile scaling bottleneck.
* **3. 100% Deterministic (Handcrafted Cypher):** 100% safe, zero agility.

### 1.1 100% Non-Deterministic (Raw Text-to-Cypher)
The LLM receives the graph schema (or a serialized graph definition) alongside the user's natural language question in its prompt, and is instructed to generate an executable Cypher query from scratch.

* **Advantages:** Unmatched expressive freedom. The model can dynamically compose complex `MATCH`, `WHERE`, `WITH`, and aggregation clauses for arbitrary questions.
* **Production Failure Modes:**
  * **Schema Hallucination:** The model fabricates node labels, relationship types, or slightly misspelled property names (e.g., generating `plantId` or `factory_code` instead of the canonical `plant_id`).
  * **Syntax & Semantic Failures:** Bracket mismatches, invalid type conversions, or illegal clause orderings occur intermittently.
  * **Security & Injection Risks:** Filtering values are frequently concatenated directly into Cypher strings, making query governance and injection prevention nearly impossible.
  * **Database Denial of Service:** Missing label qualifiers or unbounded variable-length path expansions (`-[*]-`) cause catastrophic full-graph scans and Cartesian products that lock production database instances.

While raw Text-to-Cypher makes for an impressive prototype demo, enterprise security and platform teams will rarely approve it for mission-critical production systems.

### 1.2 100% Deterministic (Handwritten / Fixed Queries)
Engineers write, index-tune, and hardcode predefined Cypher queries in code, safely binding runtime parameters via prepared statements.

* **Advantages:** 100% execution safety, guaranteed determinism, complete auditability, and predictable latency.
* **Production Failure Modes:**
  * **Zero Natural Language Agility:** The system cannot accommodate query variations, slight nuance changes, secondary filter criteria, or altered sort orders.
  * **Degrades to a Standard Form UI:** If every nuance requires a dedicated query endpoint, the system offers no real AI agent value over traditional UI forms and filter dropdowns.

### 1.3 Current Hybrid (Agent Skills + Template Selection)
To bypass the extremes of raw generation and rigid hardcoding, most teams settle on this pattern:

1. Engineers author a library of pre-vetted **Cypher templates** for anticipated business use cases.
2. Each template is wrapped in an **Agent Skill / Tool definition** with parameter schemas and natural language descriptions.
3. Upon receiving a user prompt, the LLM performs **intent classification and slot filling** via tool calling, choosing which template to invoke and extracting arguments.
4. The application safely binds these arguments into the selected template and executes it against Neo4j.

Because tool classification is a well-conditioned task for modern frontier LLMs and syntax errors are eliminated, this hybrid pattern feels like an engineering triumph—initially.

---

## 2. The Template Maintenance Wall

After several months in production, the hybrid approach invariably hits an operational ceiling.

### The Granularity of Flexibility is Bound 1:1 to Template Count
In the hybrid model, the agent’s expressive range is strictly limited to the templates human engineers have manually constructed:

* *"Who is the primary supplier of Component A?"* → Template 1
* *"Recursively expand secondary suppliers for Component A."* → Template 2
* *"List suppliers of Component A restricted to domestic plants."* → Template 3
* *"What SKUs are impacted if Supplier X halts operations?"* → Template 4

In reality, business users combine filters, path depths, aggregation dimensions, and sort orders in combinatorial permutations. Every time a business user phrases an unexpected question, the engineering backlog receives yet another request: *"Please create a new Cypher template."*

### Regression Costs Under Schema Evolution
Enterprise graphs and ontologies are living artifacts. Business growth triggers constant schema migrations: renaming node labels, introducing intermediate junction nodes, or splitting properties.

When a single entity or relationship in the schema changes, developers must:
1. Manually audit dozens or hundreds of sprawling Cypher templates to identify affected queries.
2. Rewrite the Cypher strings and pass code reviews.
3. Update the natural language descriptions across Agent Skill definitions to help the LLM maintain clear classification boundaries.
4. Re-run extensive classification evaluation sets to prevent tool-selection regression.

> **The Shift of Friction:**  
> • **Raw Text-to-Cypher:** Plagued by runtime LLM hallucinations, security injections, and DB crash risks.  
> • *(Mitigate risk by hardcoding templates)*  
> • **Hybrid Approach (Agent Skills):** Trapped in an endless cycle of human template authoring, maintenance, and regression testing.

**The hybrid approach does not solve the root problem. It merely transfers the friction from generative hallucination risk to human engineering overhead.**

---

## 3. Insights from Recent Neo4j and Academic Research

This tension between non-deterministic generation and template maintenance is a universal challenge across the graph database community. The Neo4j engineering and research ecosystem has produced significant work addressing this exact friction.

Here are the three major research frontiers:

### 1. Schema Filtering
* **Key Source:** Ozsoy (2025) – [*Enhancing Text2Cypher with Schema Filtering*](https://arxiv.org/abs/2505.05118)
* **The Insight:** Dumping massive enterprise schemas into LLM prompts degrades model attention and causes severe misclassification.
* **The Technique:** Uses exact matching, Named Entity Recognition (NER), and semantic vector similarity to dynamically prune the schema subgraph before feeding it into the prompt.

### 2. Iterative Refinement
* **Key Source:** Neo4j Developer Blog (2025) – [*Explore iterative refinement for Text2Cypher*](https://neo4j.com/blog/developer/iterative-refinement-for-text2cypher/)
* **The Insight:** Single-shot query generation without self-correction is unrealistic for multi-hop graph queries.
* **The Technique:** Evaluates generated Cypher using static syntax checkers, formal semantic verifiers (CyVer), and database execution feedback, executing a self-healing *Verify → Correct* loop.

### 3. Difficulty-Adaptive Spend
* **Key Source:** [Wang et al. (NAACL 2025 Findings)](https://aclanthology.org/2025.findings-naacl.383/), [Damani et al. (ICLR 2025)](https://arxiv.org/abs/2410.04707)
* **The Insight:** Treating all queries with the same compute budget is inefficient.
* **The Technique:** Predicts query difficulty dynamically: simple questions execute in a single low-cost pass, while complex analytical queries receive multi-turn reflection, richer schema context, and verification budgets.

### The Power—and Limitations—of Post-Hoc Verification
These research tracks offer valuable insights for production engineering:
* Dynamic pruning reduces classification errors (motivating **Schema Filtering**).
* Verification loops catch syntactic mistakes (motivating **Iterative Refinement**).

However, these approaches share a foundational assumption: **the LLM is still tasked with generating the raw Cypher query string directly.**

As long as the model writes Cypher strings, post-hoc verification loops cannot fully eliminate three structural risks:

1. **The Silent False Positive Problem:** A query can be syntactically immaculate, conform to schema constraints, and execute successfully in Neo4j without error—yet traverse completely incorrect business paths or aggregate the wrong attributes. Formal verifiers cannot detect semantic mismatch against unexpressed business rules.
2. **Fragile Parameter Separation:** Literal filter values remain intertwined with query syntax, compromising strict parameter binding and making security audits cumbersome.
3. **Non-Deterministic Auditability:** Repeated queries over time may yield subtly different Cypher structures, complicating performance profiling, query planning, and compliance audits.

Modern research improvements, while mathematically and empirically sound, act primarily as **symptomatic treatments** on top of an unconstrained generative foundation. Bridging enterprise determinism with natural language flexibility requires a deeper architectural shift.

---

## 4. Architectural Comparison: The Problem Landscape

How do the prevailing methodologies compare against the proposed **Intent-First** architecture? Here is the breakdown across key enterprise criteria:

### Approach 1: 100% Deterministic (Handcrafted / Fixed Queries)
* **Natural Language Agility:** ✕ Virtually zero (rigid dropdown-level experience).
* **Syntax & Injection Safety:** ◎ Guaranteed 100%.
* **Schema Hallucination:** None.
* **Maintenance Burden:** Linear with the number of business queries.
* **Execution Auditability:** ◎ 100% deterministic.

### Approach 2: 100% Non-Deterministic (Raw Text-to-Cypher)
* **Natural Language Agility:** ◎ Extremely high.
* **Syntax & Injection Safety:** ✕ Highly fragile (injection vectors & Cartesian blowups).
* **Schema Hallucination:** Frequent and severe.
* **Maintenance Burden:** Ongoing prompt engineering and fragile guardrails.
* **Execution Auditability:** ✕ Non-deterministic (stochastic variations).

### Approach 3: Current Hybrid (Agent Skills + Template Selection)
* **Natural Language Agility:** △ Strictly bounded by pre-written template catalog.
* **Syntax & Injection Safety:** ○ Guaranteed by approved templates.
* **Schema Hallucination:** None (within template bounds).
* **Maintenance Burden:** **Exponential template explosion & heavy regression overhead.**
* **Execution Auditability:** ○ Trackable per template ID.

### Approach 4: Advanced Research (Schema Filtering + Iterative Refinement)
* **Natural Language Agility:** ○ High.
* **Syntax & Injection Safety:** △ Relies on post-hoc verification loops.
* **Schema Hallucination:** Reduced, but silent false positives persist.
* **Maintenance Burden:** Complex verification rules, schema pruners, and repair prompts.
* **Execution Auditability:** △ Fluctuates across retry loops.

### Approach 5 (Proposed): Intent-First (Ontographia)
* **Natural Language Agility:** **◎ Combinatorial freedom across the entire ontology vocabulary.**
* **Syntax & Injection Safety:** **◎ 100% guaranteed by deterministic AST compiler and prepared `$param_N` bindings.**
* **Schema Hallucination:** **None (strictly intercepted at the ontology boundary).**
* **Maintenance Burden:** **Single Source of Truth (maintain only the Canonical Ontology definition).**
* **Execution Auditability:** **◎ 100% deterministic AST-to-Cypher emission.**
* **LLM Responsibility:** **Confined solely to structured Intent JSON extraction.**

What enterprise environments require is the simultaneous achievement of two non-negotiable criteria:
> **1. Completely eliminate non-deterministic failure modes (hallucinations, syntax errors, security injections, Cartesian blowups).**  
> **2. Eliminate the exponential maintenance overhead of manual templates, enabling the system to scale safely.**

---

## 5. The Solution: The Intent-First Hypothesis

To resolve this dilemma, we must decouple natural language flexibility from template count.

This is the core premise of **Ontographia**: **The Intent-First Hypothesis**.

*(Refer to the header illustration above for the visual pipeline)*

### The Two-Tier Architectural Pipeline

**Tier 1: Application & Agent Layer (Stochastic / LLM)**
* User submits a **Natural Language Query**.
* The LLM acts exclusively as an Intent Extractor, outputting a structured **Intent JSON** (specifying target concepts, traversal relationships, and filter conditions).

**Tier 2: Ontographia Core Layer (100% Deterministic Engine)**
* **Step A (Validation):** `validate_intent()` checks all entities, relationships, and attributes against the **Canonical Ontology (Single Source of Truth)**. Any unrecognized vocabulary is rejected immediately.
* **Step B (AST Lowering):** The validated intent is converted into a dialect-neutral **Query AST** (Abstract Syntax Tree).
* **Step C (Deterministic Emission):** The AST compiles deterministically into production-grade Cypher, automatically binding literal values into parameterized slots (`$param_N`).
* **Step D (Execution):** The hardened Cypher executes safely against the **Neo4j Database**.

### Four Foundational Design Principles

1. **Restrict the LLM Strictly to Intent Extraction (Intent JSON):**  
   The LLM never writes a single token of Cypher. Its sole responsibility is to map user natural language into an abstract, structured schema (`Intent JSON`): specifying target entity concepts, traversal relationships, filter conditions, and projected attributes.

2. **The Canonical Ontology as the Single Source of Truth (SSoT):**  
   Every class name, relationship type, and attribute key specified in the `Intent JSON` is mechanically validated against the registered Canonical Ontology. Any hallucinated vocabulary is rejected at the gate before reaching the query generator.

3. **100% Deterministic Cypher Compilation via Query AST:**  
   Validated Intent objects are transformed into a dialect-neutral Abstract Syntax Tree (`Query AST`), which deterministically emits optimized, safe Cypher (e.g., Cypher 25). Filter values are automatically extracted and bound to `$param_N` parameter maps, structurally eliminating injection vectors.

4. **Mapping Research Insights to the Intent Layer:**  
   The breakthroughs from modern research (Schema Filtering, Iterative Refinement) are retained, but relocated. Instead of filtering Cypher strings or repairing invalid syntax, we apply these techniques at the **Intent boundary in the application layer**:
   * *Schema Filtering* becomes **dynamic ontology subsetting** before prompt injection.
   * *Iterative Refinement* becomes **Intent-level schema realignment** guided by database execution feedback (such as empty result sets on valid syntax).

Under this architecture, the agent handles user queries across the **combinatorial vocabulary space of the ontology**. Teams no longer build new templates for each user phrasing, while completely insulating the database from stochastic query generation.

---

## 6. Series Roadmap

In this three-part series, we share the complete architecture, implementation details, and benchmark evaluations of the Intent-first paradigm:

* **Ontographia Part 2 - Intent-First Design and Implementation: Deterministic Cypher Assembly** *(Upcoming)*  
  * Architectural boundaries: Why the LLM must remain outside the core engine.  
  * Technical deep-dive into the Canonical Ontology Model (COM), Intent JSON Schema, AST structure, and parameterized code generation.  
  * Three extension designs mapping recent Neo4j research (Filtering, Refine, Adaptive Spend) onto the Intent layer.
* **Ontographia Part 3 - Empirical Validation and Roadmap: Large-Scale Ontology Evaluation and External Validity** *(Upcoming)*  
  * The reality of "Silent False Positives" in massive enterprise ontologies: why syntactically valid queries still misfire.  
  * Empirical validation across three hypotheses (H1: 91% token reduction and error elimination via dynamic subsetting; H2: Feedback-driven self-healing of Empty@Valid states; H3: Difficulty-adaptive allocation for minimal TCO).  
  * External validity validation across 15 official Neo4j public benchmark databases.

---

## Key Takeaways

* In natural language graph querying, **raw Text-to-Cypher is too hazardous, while handcrafted queries are too rigid**.
* The popular **hybrid model (Agent Skills + Template Selection) merely relocates friction**, shifting the bottleneck to human template maintenance and regression management.
* SOTA research methods like Schema Filtering and Iterative Refinement provide critical insights, but remain symptomatic as long as the LLM directly generates Cypher.
* The sustainable path forward is **Intent-First**: **LLMs extract structured Intent; an ontology-constrained compiler deterministically produces Cypher.**

In **Part 2** (coming soon), we explore the architectural design and concrete implementation of Ontographia, covering the high-performance Rust core, lightweight bindings, and the application-layer LLM execution loop.

👉 **Next: Look out for Part 2 — Intent-First Design and Implementation (Coming soon)**

---

*Open Source Project:* [github.com/edgesentry/ontographia](https://github.com/edgesentry/ontographia)  
*Documentation:* [edgesentry.github.io/ontographia](https://edgesentry.github.io/ontographia/)  
*Author:* Yohei Onishi  
*Tags:* `#Neo4j #Cypher #KnowledgeGraph #GraphRAG #AIAgents #EnterpriseAI #DataEngineering`
