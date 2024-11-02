module GraphicalNhlStandings

import HTTP
import JSON
import Plots

using Dates

export fetch_schedule
export plot_standings
export TEAMS

struct Team
    abbrev::String
    location::String
    name::String
    color::String
end

TEAMS = split("ANA BOS BUF CAR CBJ CGY CHI COL DAL DET EDM FLA LAK MIN MTL NJD NSH NYI NYR OTT PHI PIT SEA SJS STL TBL TOR UTA VAN VGK WPG WSH")
TEAMCOLORS = Dict(
  "ANA" => "#B9975B",
  "ARI" => "#8C2633",
  "BOS" => "#FFB81C",
  "BUF" => "#002654",
  "CGY" => "#C8102E",
  "CAR" => "#CC0000",
  "CHI" => "#CF0A2C",
  "COL" => "#6F263D",
  "CBJ" => "#002654",
  "DAL" => "#00843D",
  "DET" => "#CE1126",
  "EDM" => "#FF4C00",
  "FLA" => "#C8102E",
  "LAK" => "#111111",
  "MIN" => "#154734",
  "MTL" => "#AF1E2D",
  "NSH" => "#FFB81C",
  "NJD" => "#CE1126",
  "NYI" => "#00539B",
  "NYR" => "#0033A0",
  "OTT" => "#E31837",
  "PHI" => "#F74902",
  "PIT" => "#FCB514",
  "SEA" => "#99D9D9",
  "SJS" => "#006D75",
  "STL" => "#002F87",
  "TBL" => "#002868",
  "TOR" => "#00205B",
  "UTA" => "#71AFE5",
  "VAN" => "#001F5E",
  "VGK" => "#B4975A",
  "WSH" => "#E51837",
  "WPG" => "#041E42",
)


const API_URL = "https://api-web.nhle.com/v1"

function fetch_schedule(team_abbr; season_id=20242025, save=false)
    url = "$API_URL/club-schedule-season/$team_abbr/$season_id"
    println("Fetching $url")
    req = HTTP.get(url)
    schedule = JSON.parse(String(req.body))
    if save
        mkpath("schedules")
        write("schedules/$team_abbr.json", JSON.json(schedule))
    end
    schedule
end

function read_cached_schedule(team_abbr)
    file_contents = read("schedules/$team_abbr.json", String)
    schedule = JSON.parse(file_contents)
    schedule
end

is_regular_season_game(game) = game["gameType"] == 2
is_finished(game) = game["gameState"] in ("FINAL", "OFF")
gamedate(game) = Date(game["gameDate"])

function team_points(team_abbr, game)
    home_score = game["homeTeam"]["score"]
    away_score = game["awayTeam"]["score"]
    if game["homeTeam"]["abbrev"] == team_abbr
        score, opp_score = home_score, away_score
    elseif game["awayTeam"]["abbrev"] == team_abbr
        score, opp_score = away_score, home_score
    else
        error("invalid team_abbr $team_abbr")
    end
    
    last_period = game["gameOutcome"]["lastPeriodType"]
    if score > opp_score
        2
    elseif last_period != "REG"
        1
    else
        0
    end
end

function gamelabel(game)
    date = gamedate(game)
    home = game["homeTeam"]["abbrev"]
    away = game["awayTeam"]["abbrev"]
    home_score = game["homeTeam"]["score"]
    away_score = game["awayTeam"]["score"]
    "$date $home $home_score - $away_score $away"
end

function team_data(team_abbr, schedule)
    games = [g for g in schedule["games"] if is_finished(g) && is_regular_season_game(g)]
    points = [team_points(team_abbr, g) for g in games]
    labels = [gamelabel(g) for g in games]
    (collect(eachindex(points)), accumulate(+, points .- 1), labels)
end

function plot_standings(get_schedule=read_cached_schedule)
    Plots.plotly()

    for team_abbr in TEAMS
        println("Plotting $team_abbr...")

        schedule = get_schedule(team_abbr)

        time_series, plusminus, game_labels = team_data(team_abbr, schedule)

        # start from 0
        time_series = [0, time_series...]
        plusminus = [0, plusminus...]
        hoverlabels = ["", game_labels...]

        # small random offset so lines don't perfectly overlap
        plusminus = plusminus .+ rand(-0.1:0.01:0.1)

        Plots.plot!(
            time_series,
            plusminus,
            hover=hoverlabels,
            label=team_abbr,
            width=3,
            color=TEAMCOLORS[team_abbr]
        )
        Plots.annotate!([(time_series[end], plusminus[end], (team_abbr, 8, :left))])
    end
    now = today()
    Plots.title!("NHL Standings $now")
    Plots.plot!(
        legend=:outertopright,
        size=(1400, 1000),
    )
    Plots.savefig("standings.html")
    println("Saved figure as standings.html")
end

end
