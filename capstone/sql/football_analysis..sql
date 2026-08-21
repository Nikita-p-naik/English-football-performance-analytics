/* ============================================================================
   PROJECT      : English Football Club Performance Analytics
   DOMAIN        : Sports
   PROJECT TYPE  : Capstone Project (Portfolio)

   PIPELINE      : Phase 1 - Python (Pandas)  -> data cleaning, feature
                             engineering & EDA
                   Phase 2 - MySQL (this file) -> structured query analysis
                   Phase 3 - Power BI          -> interactive dashboard /
                             presentation layer for stakeholders

   DATA SOURCE   : England football match results dataset
   SOURCE DETAIL : Raw dataset spans 1888-2025 (208,028 matches, 12 columns),
                   cleaned and feature-engineered in Python (see companion
                   notebook: England_Football_Data_Cleaning_and_EDA.ipynb)

   DATASET USED IN THIS FILE (post Python cleaning):
       File name     : england_2020_2025.csv
       Date range    : 2020 - 2025 (most recent 5 full seasons)
       Total rows    : 8,882 matches
       File size     : 0.66 MB
       Reason scoped : Full 1888-2025 history (208,028 rows) adds unnecessary
                        load/query overhead for this project's timeline, so
                        the analysis is scoped to the current 5-year window.

   DATABASE      : football_db
   TABLE         : england_match
   TOOL          : MySQL

   CONTENTS      : 24 queries covering match-level analysis, team-level
                   performance, home-advantage trends, and ranking logic
                   (aggregation, CTEs, CASE, window functions).
   ============================================================================ */


/* ----------------------------------------------------------------------------
   DATABASE SETUP
---------------------------------------------------------------------------- */

-- Create the project database
CREATE DATABASE football_db;

-- Select the database for use
USE football_db;

-- Validate that all records were imported correctly
SELECT * FROM england_match;


/* ============================================================================
   SECTION 1 : MATCH-LEVEL ANALYSIS  (Queries 1-12)
   ============================================================================ */

/* Q1. How many matches are present in the dataset? */
SELECT COUNT(*) AS total_match
FROM england_match;


/* Q2. What is the earliest and latest match date? */
SELECT MIN(DATE) AS early_match_date, MAX(date) AS latest_match_date
FROM england_match;


/* Q3. How many unique teams are present? */
WITH all_team AS (
    SELECT home AS total_team FROM england_match
    UNION
    SELECT visitor AS total_team FROM england_match
)
SELECT COUNT(*) AS total_team
FROM all_team;


/* Q4. How many matches were played in each division? */
SELECT division, COUNT(*) AS matches_played
FROM england_match
GROUP BY division;


/* Q5. What is the total number of goals scored? */
SELECT SUM(totgoal) AS total_goals
FROM england_match;


/* Q6. What is the average number of goals per match? */
SELECT ROUND(AVG(totgoal), 0) AS avg_goals
FROM england_match;


/* Q7. How many matches were won at home, drawn, and won away? */
SELECT
    match_result,
    COUNT(*) AS match_won,
    ROUND((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM england_match
GROUP BY match_result
ORDER BY match_won DESC;


/* Q8. Which seasons had the highest total goals? */
SELECT season, SUM(totgoal) AS highest_goal
FROM england_match
GROUP BY season
ORDER BY 2 DESC;


/* Q9. Which divisions have the highest average goals per match? */
SELECT
    division,
    ROUND(AVG(totgoal), 0) AS highest_avg_goal,
    COUNT(*) AS match_played
FROM england_match
GROUP BY division
ORDER BY match_played DESC;


/* Q10. What is the average goal difference by season? */
SELECT
    season,
    ROUND(AVG(goaldif), 2) AS average_goal_difference,
    COUNT(*) AS match_played
FROM england_match
GROUP BY season
ORDER BY match_played DESC;


/* Q11. Classify matches by total goals:
        0-1 = Low Scoring, 2-3 = Moderate Scoring, 4+ = High Scoring (CASE). */
SELECT
    CASE
        WHEN totgoal <= 1 THEN 'Low Score'
        WHEN totgoal BETWEEN 2 AND 3 THEN 'Moderate Score'
        ELSE 'High score'
    END AS score_classfication,
    COUNT(*) AS total_match,
    ROUND((COUNT(*) * 100) / SUM(COUNT(*)) OVER(), 2) AS percent_share
FROM england_match
GROUP BY 1
ORDER BY total_match DESC;


/* Q12. Identify high-margin victories (e.g. goal difference >= 3). */
SELECT
    season,
    COUNT(*) AS high_margin_victory,
    ROUND((COUNT(*) * 100) / SUM(COUNT(*)) OVER(), 2) AS blawout_percent
FROM england_match
WHERE goaldif >= 3 OR goaldif <= -3
GROUP BY season
ORDER BY high_margin_victory DESC;



/* ============================================================================
   SECTION 2 : TEAM-LEVEL ANALYSIS  (Queries 13-19)
   ============================================================================ */

/* Q13. Comprehensive Team Performance Standings (Home + Away Combined). */
WITH team_matrix AS (
    SELECT
        home AS team, 1 AS match_played, home_win AS win, away_win AS loss,
        draw, hgoal AS goal_scored, vgoal AS goal_conceded
    FROM england_match
    UNION ALL
    SELECT
        visitor AS team, 1 AS match_played, home_win AS win, away_win AS loss,
        draw, hgoal AS goal_scored, vgoal AS goal_conceded
    FROM england_match
)
SELECT
    team,
    SUM(match_played) AS total_match,
    SUM(win) AS total_win,
    SUM(loss) AS Total_loss,
    SUM(draw) AS total_draw,
    ROUND((SUM(win) * 100.0) / SUM(match_played), 2) AS win_rate_percentage,
    SUM(goal_scored) AS total_goal_scored,
    SUM(goal_conceded) AS total_goal_conceded,
    SUM(goal_scored) - SUM(goal_conceded) AS total_goal_difference
FROM team_matrix
GROUP BY team
ORDER BY total_win DESC, total_goal_difference DESC;


/* Q14. Which teams have the most home wins? */
SELECT
    home AS team_name,
    COUNT(*) AS total_home_matches,
    SUM(CASE WHEN TRIM(match_result) = 'Home Win' THEN 1 ELSE 0 END) AS total_home_wins,
    ROUND(SUM(CASE WHEN TRIM(match_result) = 'Home Win' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS home_win_percentage
FROM england_match
GROUP BY home
ORDER BY total_home_wins DESC
LIMIT 10;


/* Q15. Which teams have the most away wins? */
SELECT
    visitor AS team_name,
    COUNT(*) AS total_away_matches,
    SUM(CASE WHEN TRIM(match_result) = 'Away Win' THEN 1 ELSE 0 END) AS total_away_wins,
    ROUND(SUM(CASE WHEN TRIM(match_result) = 'Away Win' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS away_win_percentage
FROM england_match
GROUP BY visitor
ORDER BY total_away_wins DESC
LIMIT 10;


/* Q16. Which teams have scored the most goals? */
WITH team_goals_stream AS (
    SELECT home AS team_name, hgoal AS goals FROM england_match
    UNION ALL
    SELECT visitor AS team_name, vgoal AS goals FROM england_match
)
SELECT
    team_name,
    COUNT(*) AS total_matches_played,
    SUM(goals) AS total_goals_scored,
    ROUND(AVG(goals), 2) AS average_goals_per_match
FROM team_goals_stream
GROUP BY team_name
ORDER BY total_goals_scored DESC
LIMIT 10;


/* Q17. Top Teams by Average Goals per Match & Average Goal Difference
        (combined query, minimum 20 matches played to remove small-sample noise). */
WITH team_all_matches AS (
    SELECT
        home AS team_name,
        (hgoal + vgoal) AS match_total_goals,
        goaldif AS match_goal_difference
    FROM england_match
    UNION ALL
    SELECT
        visitor AS team_name,
        (vgoal + hgoal) AS match_total_goals,
        (vgoal - hgoal) AS match_goal_difference
    FROM england_match
)
SELECT
    team_name,
    COUNT(*) AS total_matches_played,
    ROUND(AVG(match_total_goals), 2) AS avg_goals_per_match,
    ROUND(AVG(match_goal_difference), 2) AS avg_goal_difference
FROM team_all_matches
GROUP BY team_name
HAVING COUNT(*) >= 20
ORDER BY avg_goals_per_match DESC;


/* Q18. Which teams have the highest average goals per match?
        NOTE: No separate query required — answered directly from the Q17
        result set above, re-sorted by avg_goals_per_match (its existing
        default sort order). See portfolio report for the extracted top 10. */

/* Q19. Which teams have the highest average goal difference?
        NOTE: No separate query required — answered directly from the Q17
        result set above, re-sorted by avg_goal_difference DESC.
        See portfolio report for the extracted top 10. */



/* ============================================================================
   SECTION 3 : TIME TRENDS & RANKING ANALYSIS  (Queries 20-24)
   ============================================================================ */

/* Q20. Compare overall Home Win % vs Away Win % vs Draw % (2020-2025). */
SELECT
    COUNT(*) AS total_matches,
    ROUND(SUM(CASE WHEN TRIM(match_result) = 'Home Win' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS home_win_percentage,
    ROUND(SUM(CASE WHEN TRIM(match_result) = 'Away Win' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS away_win_percentage,
    ROUND(SUM(CASE WHEN TRIM(match_result) LIKE 'Draw%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS draw_percentage
FROM england_match;


/* Q21. How has the home-win percentage changed over time? */
SELECT
    Year,
    COUNT(*) AS total_matches_played,
    ROUND(SUM(CASE WHEN TRIM(match_result) = 'Home Win' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS yearly_home_win_percentage
FROM england_match
GROUP BY Year
ORDER BY Year ASC;


/* Q22. Rank teams by total goals scored (RANK vs DENSE_RANK). */
WITH team_goal_totals AS (
    SELECT home AS team_name, hgoal AS goals_scored FROM england_match
    UNION ALL
    SELECT visitor AS team_name, vgoal AS goals_scored FROM england_match
),
total_scores AS (
    SELECT
        team_name,
        SUM(goals_scored) AS total_goals
    FROM team_goal_totals
    GROUP BY team_name
)
SELECT
    team_name,
    total_goals,
    RANK() OVER(ORDER BY total_goals DESC) AS absolute_rank,
    DENSE_RANK() OVER(ORDER BY total_goals DESC) AS dense_rank_no_gap
FROM total_scores
ORDER BY dense_rank_no_gap DESC;


/* Q23. Which season had the highest scoring rate? */
SELECT
    season,
    COUNT(*) AS total_matches,
    SUM(totgoal) AS total_goals,
    ROUND(AVG(totgoal), 2) AS scoring_rate_per_match
FROM england_match
GROUP BY season
ORDER BY scoring_rate_per_match DESC;


/* Q24. How many matches were played each season? */
SELECT season, COUNT(*) AS total_matches_played
FROM england_match
GROUP BY season
ORDER BY season ASC;



/* ============================================================================
   END OF MYSQL ANALYSIS PHASE (PHASE 2)

   SUMMARY
   --------
   - 24 queries executed against 8,882 matches (2020-2025) in football_db.
   - Techniques used: aggregation (GROUP BY / SUM / AVG / COUNT), CASE-based
     classification, CTEs, UNION / UNION ALL, and window functions
     (RANK, DENSE_RANK, and windowed percentage calculations via OVER()).
   - Full query-by-query outputs and written insights are documented in the
     companion portfolio report: English_Football_SQL_Portfolio.docx

   NEXT STEP - PHASE 3 : POWER BI
   -------------------------------
   The results from this MySQL analysis will be brought into Power BI to
   build an interactive dashboard/presentation layer, covering:
       - Season-by-season trends in matches played, goals, and scoring rate
       - Home vs away win percentage, overall and over time
       - Top-performing teams by wins, goals scored, and goal difference
       - Division-level comparisons
   This will serve as the final, stakeholder-facing deliverable of the
   capstone project.
   ============================================================================ */
