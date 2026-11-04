# Portfolio 1: Database Design and Modelling

**Course:** MIT 8103 Advanced Database Systems
**Case study:** Afordchess Academy, a chess coaching and education business

## Selected organisation

Afordchess Academy is a chess coaching and education business that delivers mostly online classes, plus in-person classes run by its staff in partner schools, to students in Nigeria, Canada and the USA. Students pay a monthly fee in their local currency, and the academy promotes itself through Instagram, TikTok and YouTube content. The database users are the owner, coaches, administrative and marketing staff, and (through enrolment and billing) students and their guardians. The major data stored is staff, partner schools, students and guardians, courses and prices, class sessions, enrolments, attendance, monthly payments, social media accounts, posts and their engagement metrics, and leads showing where each new student came from. Key operations include enrolling a student, scheduling online and in-person sessions, booking seats and recording attendance, billing and recording monthly payments, publishing and tracking posts, and reporting on which content brings in paying students.

Afordchess Academy is a real organisation, but all data used in this repository is invented. No real student, guardian or payment records are used.

## Files in this folder

- `schema.sql`: the full PostgreSQL schema (14 tables with keys and constraints).
- `er-diagram.png`: the ER diagram (to be added).
- `evidence/`: screenshots showing that the schema ran successfully (to be added).

## How it was implemented and tested

The schema was written for PostgreSQL and run in the Supabase SQL Editor. The script begins with `DROP TABLE IF EXISTS` statements, so it can be re-run safely. After running it, the tables were checked in the Table Editor and test inserts were used to confirm that the constraints reject bad data, for example a duplicate email, a payment in the wrong currency, or an in-person session with no school. Screenshots of these checks are in `evidence/`.

## Design overview

The 14 tables fall into four groups.

- **People and places:** `staff` (owner, coaches, admin and marketing, told apart by a `role` column), `schools` (partner schools), `guardians` (parents who pay for younger students) and `students`. A student's guardian and school are optional, because some students are adults and many learn online with no school.
- **Teaching:** `courses`, `course_prices`, `class_sessions` and `session_attendance`. Prices sit in their own table, one row per course per currency, so a course can be priced in NGN, CAD and USD without repeating columns.
- **Money:** `enrolments` and `payments`. An enrolment is a student's monthly subscription to a course, and a payment is one row per enrolment per billing month.
- **Marketing:** `social_accounts`, `posts`, `post_metrics` and `leads`. Metrics are stored as daily snapshots per post, and each lead records its source, so the academy can trace paying students back to the content that attracted them.

## Relationships

One guardian has many students, and one school has many students and many in-person sessions. One course has many prices, sessions and enrolments. A student has many enrolments, and one enrolment has many monthly payments. `session_attendance` resolves a many-to-many relationship between students and sessions, because one student attends many sessions and one session has many students. On the marketing side, one social account has many posts, one post has many daily metric rows and can bring in many leads, and a converted lead points to the student record it became.

## Keys and constraints

Every table has a primary key. Most use an auto-incrementing id, while `course_prices`, `session_attendance` and `post_metrics` use composite keys that match their natural identity (for example, one metrics row per post per day). Foreign keys link child rows to parents, and `ON DELETE CASCADE` is used only where child rows make no sense without the parent, such as attendance rows without their session. `UNIQUE` constraints prevent duplicate emails, two bills for the same enrolment in the same month, and duplicate social handles. `CHECK` constraints keep values valid: fees and amounts must be positive, currencies must be NGN, CAD or USD, and billing months must fall on the first of the month. Several checks encode business rules. An online session cannot have a school and an in-person session must have one, a paid payment must have a payment time, a social-post lead must reference a post, and a lead is marked converted only when it points to a student. Two composite foreign keys enforce currency consistency: an enrolment can only use a currency its course is priced in, and a payment must use the same currency as its enrolment.

## Normalisation

The design is in third normal form. It is in first normal form because every column holds a single value and there are no repeating groups, which is why prices are rows in `course_prices` rather than columns like `fee_ngn` and `fee_usd`. It is in second normal form because in tables with composite keys, such as `post_metrics` and `session_attendance`, every other column depends on the whole key and not on part of it. It is in third normal form because no non-key column depends on another non-key column. For example, a student's school details live only in `schools` and are reached through `school_id`, and a post's platform is reached through its account, not stored again on the post. Two deliberate snapshots are not redundancy. `enrolments.agreed_monthly_fee` records the price the student agreed to, and `payments.amount` records what was billed, because list prices can change later without altering what was already agreed or owed.

## Known limitations

Some rules cannot be enforced by a `CHECK` constraint because they involve other rows or tables. A session's `capacity` is not stopped from being exceeded by bookings, and a student could be booked into a session for a course they are not enrolled in. In a production system these would be enforced with transactions and locking, triggers, or application logic. Portfolio 3 addresses the capacity case directly.

## Technical reflection
## AI use declaration

**AI tool used:** Claude (Anthropic).

**What it was used for:** I used Claude to help me understand the assignment brief and plan the portfolio. It suggested case study options, and I chose Afordchess Academy and gave it details of how the business operates (online classes, in-person classes in partner schools, students in Nigeria, Canada and the USA, monthly payments, and social media channels). Claude then drafted the PostgreSQL schema in `schema.sql`, the README structure for this portfolio, and plain-English explanations of the design, including keys, constraints and normalisation.

**How I reviewed, corrected, tested and verified the output:** I read through the schema table by table and made sure I could explain what each table and constraint is for. I ran the script in the Supabase SQL Editor and [describe what happened, e.g. whether it ran first time or what errors appeared and how they were fixed]. I tested the constraints with my own test inserts [describe at least two that you ran and what happened]. I checked that the design reflects how the academy actually works [describe anything you changed or corrected]. Screenshots of this testing are in `evidence/`.

I take responsibility for the accuracy, originality and understanding of everything in this portfolio.






