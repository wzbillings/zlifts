(function () {
  "use strict";

  var palette = [
    "#2563eb",
    "#0f766e",
    "#7c3aed",
    "#c2410c",
    "#059669",
    "#be123c",
    "#475569",
    "#a16207",
    "#0369a1",
    "#4d7c0f"
  ];

  var tableSort = {};
  var state = {
    rows: [],
    minDate: "",
    maxDate: ""
  };

  function byId(id) {
    return document.getElementById(id);
  }

  function asNumber(value) {
    if (value === null || value === undefined || value === "") {
      return null;
    }
    var number = Number(value);
    return Number.isFinite(number) ? number : null;
  }

  function numberOrZero(value) {
    var number = asNumber(value);
    return number === null ? 0 : number;
  }

  function formatNumber(value, digits) {
    var number = asNumber(value);
    if (number === null) {
      return "Missing";
    }
    return number.toLocaleString(undefined, {
      maximumFractionDigits: digits === undefined ? 0 : digits
    });
  }

  function formatInteger(value) {
    return formatNumber(value, 0);
  }

  function formatLb(value) {
    var number = asNumber(value);
    return number === null ? "Missing" : formatNumber(number, 0) + " lb";
  }

  function formatChange(value, hasRepeated) {
    var number = asNumber(value);
    if (!hasRepeated || number === null) {
      return "Needs repeat";
    }
    if (number > 0) {
      return "+" + formatNumber(number, 0) + " lb";
    }
    if (number < 0) {
      return formatNumber(number, 0) + " lb";
    }
    return "0 lb";
  }

  function titleCase(value) {
    return String(value || "unknown")
      .replace(/[_-]+/g, " ")
      .replace(/\w\S*/g, function (part) {
        return part.charAt(0).toUpperCase() + part.slice(1).toLowerCase();
      });
  }

  function normalizeRow(row) {
    var normalized = Object.assign({}, row);
    normalized.activity_id = String(row.activity_id || "");
    normalized.date = String(row.date || "");
    normalized.workout_name = row.workout_name || "Workout";
    normalized.exercise = row.exercise || row.exercise_raw || "Unknown exercise";
    normalized.equipment_type = row.equipment_type || "unknown";
    normalized.equipment_label = row.equipment_label || titleCase(normalized.equipment_type);
    normalized.exercise_label = row.exercise_label || normalized.exercise;
    normalized.movement_group = row.movement_group || "Unknown";
    normalized.set_number = asNumber(row.set_number);
    normalized.reps = asNumber(row.reps);
    normalized.weight_lb = asNumber(row.weight_lb);
    normalized.volume_lb = asNumber(row.volume_lb);
    normalized.garmin_volume_lb = asNumber(row.garmin_volume_lb);
    normalized.time_seconds = asNumber(row.time_seconds);
    normalized.rest_seconds = asNumber(row.rest_seconds);

    if (normalized.volume_lb === null && normalized.reps !== null && normalized.weight_lb !== null) {
      normalized.volume_lb = normalized.reps * normalized.weight_lb;
    }

    return normalized;
  }

  function readPayload() {
    var dataElement = byId("zlifts-dashboard-data");
    if (!dataElement) {
      return { rows: [] };
    }

    try {
      return JSON.parse(dataElement.textContent || "{\"rows\":[]}");
    } catch (error) {
      console.error("Could not parse dashboard data", error);
      return { rows: [] };
    }
  }

  function uniqueValues(rows, field) {
    var values = new Set();
    rows.forEach(function (row) {
      var value = row[field];
      if (value !== null && value !== undefined && String(value).trim() !== "") {
        values.add(String(value));
      }
    });
    return Array.from(values).sort(function (a, b) {
      return a.localeCompare(b, undefined, { sensitivity: "base" });
    });
  }

  function selectedValues(select) {
    if (!select) {
      return [];
    }
    return Array.from(select.selectedOptions).map(function (option) {
      return option.value;
    });
  }

  function activeSelectValues(select) {
    if (!select) {
      return null;
    }
    var options = Array.from(select.options);
    var selected = selectedValues(select);
    if (selected.length === 0 || selected.length === options.length) {
      return null;
    }
    return new Set(selected);
  }

  function buildFilters(excludeField) {
    var filters = {};
    var start = byId("date-start-filter");
    var end = byId("date-end-filter");

    if (excludeField !== "date") {
      filters.startDate = start && start.value ? start.value : state.minDate;
      filters.endDate = end && end.value ? end.value : state.maxDate;
    }
    if (excludeField !== "exercise") {
      filters.exercise = activeSelectValues(byId("exercise-filter"));
    }
    if (excludeField !== "movement_group") {
      filters.movement_group = activeSelectValues(byId("movement-filter"));
    }
    if (excludeField !== "equipment_type") {
      filters.equipment_type = activeSelectValues(byId("equipment-filter"));
    }

    return filters;
  }

  function rowMatches(row, filters) {
    if (filters.startDate && row.date < filters.startDate) {
      return false;
    }
    if (filters.endDate && row.date > filters.endDate) {
      return false;
    }
    if (filters.exercise && !filters.exercise.has(String(row.exercise))) {
      return false;
    }
    if (filters.movement_group && !filters.movement_group.has(String(row.movement_group))) {
      return false;
    }
    if (filters.equipment_type && !filters.equipment_type.has(String(row.equipment_type))) {
      return false;
    }
    return true;
  }

  function applyFilters(rows, filters) {
    return rows.filter(function (row) {
      return rowMatches(row, filters);
    });
  }

  function optionLabel(field, value) {
    if (field === "equipment_type") {
      return titleCase(value);
    }
    return String(value);
  }

  function populateSelect(id, field) {
    var select = byId(id);
    if (!select) {
      return;
    }

    var previousOptions = Array.from(select.options);
    var previousSelected = new Set(selectedValues(select));
    var hadActiveFilter = previousOptions.length > 0 &&
      previousSelected.size > 0 &&
      previousSelected.size < previousOptions.length;
    var availableRows = applyFilters(state.rows, buildFilters(field));
    var values = uniqueValues(availableRows, field);

    select.textContent = "";
    values.forEach(function (value) {
      var option = document.createElement("option");
      option.value = value;
      option.textContent = optionLabel(field, value);
      option.selected = hadActiveFilter ? previousSelected.has(value) : true;
      select.appendChild(option);
    });

    if (hadActiveFilter && selectedValues(select).length === 0) {
      Array.from(select.options).forEach(function (option) {
        option.selected = true;
      });
    }
  }

  function refreshLinkedFilters() {
    populateSelect("exercise-filter", "exercise");
    populateSelect("movement-filter", "movement_group");
    populateSelect("equipment-filter", "equipment_type");
  }

  function groupRows(rows, keyFunction, createFunction, updateFunction) {
    var grouped = new Map();
    rows.forEach(function (row) {
      var key = keyFunction(row);
      if (!grouped.has(key)) {
        grouped.set(key, createFunction(row));
      }
      updateFunction(grouped.get(key), row);
    });
    return Array.from(grouped.values());
  }

  function summarizeSessions(rows) {
    var sessions = groupRows(
      rows,
      function (row) { return row.activity_id; },
      function (row) {
        return {
          activity_id: row.activity_id,
          date: row.date,
          workout_name: row.workout_name,
          total_sets: 0,
          total_reps: 0,
          total_volume_lb: 0,
          exercises_set: new Set()
        };
      },
      function (session, row) {
        session.total_sets += 1;
        session.total_reps += numberOrZero(row.reps);
        session.total_volume_lb += numberOrZero(row.volume_lb);
        session.exercises_set.add(row.exercise_label);
      }
    );

    sessions.forEach(function (session) {
      session.exercises = session.exercises_set.size;
      delete session.exercises_set;
    });

    return sessions.sort(function (a, b) {
      return a.date.localeCompare(b.date) || a.activity_id.localeCompare(b.activity_id);
    });
  }

  function summarizeExercises(rows) {
    var summaries = groupRows(
      rows,
      function (row) {
        return [row.activity_id, row.date, row.exercise, row.equipment_type].join("\r");
      },
      function (row) {
        return {
          activity_id: row.activity_id,
          date: row.date,
          workout_name: row.workout_name,
          exercise: row.exercise,
          equipment_type: row.equipment_type,
          equipment_label: row.equipment_label,
          exercise_label: row.exercise_label,
          movement_group: row.movement_group,
          sets: 0,
          total_reps: 0,
          total_volume_lb: 0,
          max_weight_lb: null
        };
      },
      function (summary, row) {
        summary.sets += 1;
        summary.total_reps += numberOrZero(row.reps);
        summary.total_volume_lb += numberOrZero(row.volume_lb);
        if (row.weight_lb !== null) {
          summary.max_weight_lb = summary.max_weight_lb === null ? row.weight_lb : Math.max(summary.max_weight_lb, row.weight_lb);
        }
      }
    );

    return summaries.sort(function (a, b) {
      return a.date.localeCompare(b.date) || a.exercise_label.localeCompare(b.exercise_label);
    });
  }

  function summarizeExerciseProgress(exerciseSummaries) {
    var grouped = groupRows(
      exerciseSummaries,
      function (row) { return [row.exercise, row.equipment_type].join("\r"); },
      function (row) {
        return {
          exercise: row.exercise,
          equipment_type: row.equipment_type,
          equipment_label: row.equipment_label,
          exercise_label: row.exercise_label,
          observations: []
        };
      },
      function (summary, row) {
        summary.observations.push(row);
      }
    );

    grouped.forEach(function (summary) {
      summary.observations.sort(function (a, b) {
        return a.date.localeCompare(b.date) || a.activity_id.localeCompare(b.activity_id);
      });
      var first = summary.observations[0];
      var latest = summary.observations[summary.observations.length - 1];
      var maxWeights = summary.observations.map(function (row) { return row.max_weight_lb; }).filter(function (value) { return value !== null; });
      var volumes = summary.observations.map(function (row) { return row.total_volume_lb; }).filter(function (value) { return value !== null; });
      var hasRepeated = summary.observations.length >= 2;
      var change = hasRepeated && first.max_weight_lb !== null && latest.max_weight_lb !== null ? latest.max_weight_lb - first.max_weight_lb : null;

      summary.workout_count = summary.observations.length;
      summary.first_workout_date = first.date;
      summary.latest_workout_date = latest.date;
      summary.latest_recorded_max_weight_lb = latest.max_weight_lb;
      summary.all_time_max_weight_lb = maxWeights.length > 0 ? Math.max.apply(null, maxWeights) : null;
      summary.change_from_first_recorded_max_weight_lb = change;
      summary.latest_exercise_volume_lb = latest.total_volume_lb;
      summary.all_time_highest_exercise_volume_lb = volumes.length > 0 ? Math.max.apply(null, volumes) : null;
      summary.has_repeated_observations = hasRepeated;
      summary.progress_note = !hasRepeated ? "Only one workout recorded" :
        change === null ? "Recorded max change unavailable" :
        change > 0 ? "Recorded max up " + formatNumber(change, 0) + " lb from first logged workout" :
        change < 0 ? "Recorded max down " + formatNumber(Math.abs(change), 0) + " lb from first logged workout" :
        "Recorded max unchanged from first logged workout";
      delete summary.observations;
    });

    return grouped.sort(function (a, b) {
      var aMax = a.all_time_max_weight_lb === null ? -Infinity : a.all_time_max_weight_lb;
      var bMax = b.all_time_max_weight_lb === null ? -Infinity : b.all_time_max_weight_lb;
      return bMax - aMax || a.exercise_label.localeCompare(b.exercise_label);
    });
  }

  function baseLayout(title, yTitle) {
    return {
      title: { text: title, x: 0, xanchor: "left", font: { size: 16 } },
      margin: { t: 50, r: 24, b: 64, l: 72 },
      paper_bgcolor: "rgba(0,0,0,0)",
      plot_bgcolor: "rgba(0,0,0,0)",
      font: { family: "Inter, system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif", color: "#172033" },
      xaxis: { automargin: true, gridcolor: "#edf2f7", zeroline: false },
      yaxis: { title: yTitle, automargin: true, gridcolor: "#e5edf4", zeroline: false },
      legend: { orientation: "h", x: 0, y: -0.24 }
    };
  }

  function emptyLayout(title) {
    var layout = baseLayout(title, "");
    layout.annotations = [{
      text: "No matching sets",
      showarrow: false,
      xref: "paper",
      yref: "paper",
      x: 0.5,
      y: 0.5,
      font: { color: "#64748b", size: 14 }
    }];
    layout.xaxis.visible = false;
    layout.yaxis.visible = false;
    return layout;
  }

  function plotlyConfig() {
    return { displaylogo: false, responsive: true };
  }

  function renderEmptyChart(id, title) {
    if (window.Plotly) {
      window.Plotly.react(id, [], emptyLayout(title), plotlyConfig());
    }
  }

  function renderSessionChart(sessions) {
    if (sessions.length === 0) {
      renderEmptyChart("session-volume-chart", "Total workout volume");
      return;
    }

    window.Plotly.react("session-volume-chart", [{
      type: "bar",
      x: sessions.map(function (row) { return row.date; }),
      y: sessions.map(function (row) { return row.total_volume_lb; }),
      customdata: sessions.map(function (row) {
        return [row.workout_name, row.total_sets, row.total_reps, row.exercises];
      }),
      marker: { color: "#2563eb" },
      hovertemplate: "Date: %{x}<br>Workout: %{customdata[0]}<br>Sets: %{customdata[1]}<br>Reps: %{customdata[2]}<br>Exercises: %{customdata[3]}<br>Total volume: %{y:,.0f} lb<extra></extra>"
    }], baseLayout("Total workout volume", "Total volume (lb)"), plotlyConfig());
  }

  function tracesByLabel(rows, valueField, hoverTemplate) {
    var labels = uniqueValues(rows, "exercise_label");
    return labels.map(function (label, index) {
      var labelRows = rows.filter(function (row) { return row.exercise_label === label; });
      return {
        type: "scatter",
        mode: "lines+markers",
        name: label,
        x: labelRows.map(function (row) { return row.date; }),
        y: labelRows.map(function (row) { return row[valueField]; }),
        customdata: labelRows.map(function (row) {
          return [row.exercise, row.equipment_label, row.sets, row.total_reps, row.total_volume_lb, row.max_weight_lb];
        }),
        line: { color: palette[index % palette.length], width: 2 },
        marker: { color: palette[index % palette.length], size: 7 },
        hovertemplate: hoverTemplate
      };
    });
  }

  function renderExerciseVolumeChart(exerciseSummaries) {
    if (exerciseSummaries.length === 0) {
      renderEmptyChart("exercise-volume-chart", "Exercise training volume over time");
      return;
    }

    window.Plotly.react(
      "exercise-volume-chart",
      tracesByLabel(
        exerciseSummaries,
        "total_volume_lb",
        "Date: %{x}<br>Exercise: %{customdata[0]}<br>Type: %{customdata[1]}<br>Sets: %{customdata[2]}<br>Reps: %{customdata[3]}<br>Total volume: %{y:,.0f} lb<extra></extra>"
      ),
      baseLayout("Exercise training volume over time", "Total volume (lb)"),
      plotlyConfig()
    );
  }

  function renderMaxWeightChart(exerciseSummaries) {
    if (exerciseSummaries.length === 0) {
      renderEmptyChart("max-weight-chart", "Maximum recorded weight by exercise over time");
      return;
    }

    window.Plotly.react(
      "max-weight-chart",
      tracesByLabel(
        exerciseSummaries,
        "max_weight_lb",
        "Date: %{x}<br>Exercise: %{customdata[0]}<br>Type: %{customdata[1]}<br>Sets: %{customdata[2]}<br>Max recorded weight: %{y:,.0f} lb<br>Total volume: %{customdata[4]:,.0f} lb<extra></extra>"
      ),
      baseLayout("Maximum recorded weight by exercise over time", "Maximum recorded weight (lb)"),
      plotlyConfig()
    );
  }

  function renderSetPerformanceChart(rows) {
    if (rows.length === 0) {
      renderEmptyChart("set-performance-chart", "Set-level load and repetitions");
      return;
    }

    var labels = uniqueValues(rows, "exercise_label");
    var traces = labels.map(function (label, index) {
      var labelRows = rows.filter(function (row) { return row.exercise_label === label; });
      return {
        type: "scatter",
        mode: "markers",
        name: label,
        x: labelRows.map(function (row) { return row.date; }),
        y: labelRows.map(function (row) { return row.weight_lb; }),
        marker: {
          color: palette[index % palette.length],
          opacity: 0.72,
          size: labelRows.map(function (row) { return Math.max(7, Math.min(20, numberOrZero(row.reps) + 4)); })
        },
        customdata: labelRows.map(function (row) {
          return [row.exercise, row.equipment_label, row.set_number, row.reps, row.volume_lb, row.workout_name];
        }),
        hovertemplate: "Date: %{x}<br>Workout: %{customdata[5]}<br>Exercise: %{customdata[0]}<br>Type: %{customdata[1]}<br>Set: %{customdata[2]}<br>Weight: %{y:,.0f} lb<br>Reps: %{customdata[3]}<br>Volume: %{customdata[4]:,.0f} lb<extra></extra>"
      };
    });

    window.Plotly.react(
      "set-performance-chart",
      traces,
      baseLayout("Set-level load and repetitions", "Recorded weight (lb)"),
      plotlyConfig()
    );
  }

  function compareRows(a, b, key) {
    var aValue = a[key];
    var bValue = b[key];
    var aNumber = asNumber(aValue);
    var bNumber = asNumber(bValue);

    if (aNumber !== null && bNumber !== null) {
      return aNumber - bNumber;
    }
    return String(aValue || "").localeCompare(String(bValue || ""), undefined, { sensitivity: "base" });
  }

  function renderTable(id, rows, columns, emptyMessage) {
    var container = byId(id);
    if (!container) {
      return;
    }

    container.textContent = "";
    if (rows.length === 0) {
      var empty = document.createElement("p");
      empty.className = "zlifts-empty-state";
      empty.textContent = emptyMessage;
      container.appendChild(empty);
      return;
    }

    var sortState = tableSort[id] || { key: columns[0].key, direction: "asc" };
    var sortedRows = rows.slice().sort(function (a, b) {
      var comparison = compareRows(a, b, sortState.key);
      return sortState.direction === "asc" ? comparison : -comparison;
    });

    var table = document.createElement("table");
    table.className = "zlifts-data-table";
    var thead = document.createElement("thead");
    var headerRow = document.createElement("tr");

    columns.forEach(function (column) {
      var th = document.createElement("th");
      if (column.align === "right") {
        th.className = "numeric";
      }
      var button = document.createElement("button");
      button.type = "button";
      button.textContent = column.label + (sortState.key === column.key ? (sortState.direction === "asc" ? " ^" : " v") : "");
      button.addEventListener("click", function () {
        tableSort[id] = {
          key: column.key,
          direction: sortState.key === column.key && sortState.direction === "asc" ? "desc" : "asc"
        };
        renderTable(id, rows, columns, emptyMessage);
      });
      th.appendChild(button);
      headerRow.appendChild(th);
    });

    thead.appendChild(headerRow);
    table.appendChild(thead);

    var tbody = document.createElement("tbody");
    sortedRows.forEach(function (row) {
      var tr = document.createElement("tr");
      columns.forEach(function (column) {
        var td = document.createElement("td");
        if (column.align === "right") {
          td.className = "numeric";
        }
        td.textContent = column.format ? column.format(row[column.key], row) : String(row[column.key] || "");
        tr.appendChild(td);
      });
      tbody.appendChild(tr);
    });

    table.appendChild(tbody);
    container.appendChild(table);
  }

  function updateStatus(rows, sessions) {
    var status = byId("filter-status");
    if (!status) {
      return;
    }
    var totalVolume = rows.reduce(function (sum, row) { return sum + numberOrZero(row.volume_lb); }, 0);
    var exerciseCount = uniqueValues(rows, "exercise_label").length;
    status.textContent = formatInteger(rows.length) + " sets | " +
      formatInteger(sessions.length) + " workouts | " +
      formatInteger(exerciseCount) + " exercises | " +
      formatLb(totalVolume);
  }

  function renderDashboard() {
    if (!window.Plotly) {
      window.setTimeout(renderDashboard, 100);
      return;
    }

    var rows = applyFilters(state.rows, buildFilters());
    var sessions = summarizeSessions(rows);
    var exerciseSummaries = summarizeExercises(rows);
    var progress = summarizeExerciseProgress(exerciseSummaries);

    updateStatus(rows, sessions);
    renderSessionChart(sessions);
    renderExerciseVolumeChart(exerciseSummaries);
    renderMaxWeightChart(exerciseSummaries);
    renderSetPerformanceChart(rows);

    renderTable("exercise-progress-table", progress, [
      { key: "exercise", label: "Exercise" },
      { key: "equipment_label", label: "Type" },
      { key: "workout_count", label: "Workouts", align: "right", format: formatInteger },
      { key: "latest_recorded_max_weight_lb", label: "Latest max", align: "right", format: formatLb },
      { key: "all_time_max_weight_lb", label: "All-time max", align: "right", format: formatLb },
      { key: "change_from_first_recorded_max_weight_lb", label: "Change", align: "right", format: function (value, row) { return formatChange(value, row.has_repeated_observations); } },
      { key: "latest_exercise_volume_lb", label: "Latest volume", align: "right", format: formatLb },
      { key: "all_time_highest_exercise_volume_lb", label: "Best volume", align: "right", format: formatLb },
      { key: "progress_note", label: "Note" }
    ], "No exercises match the current filters.");

    renderTable("session-summary-table", sessions, [
      { key: "date", label: "Date" },
      { key: "activity_id", label: "Activity ID" },
      { key: "workout_name", label: "Workout" },
      { key: "total_sets", label: "Sets", align: "right", format: formatInteger },
      { key: "total_reps", label: "Reps", align: "right", format: formatInteger },
      { key: "total_volume_lb", label: "Total volume", align: "right", format: formatLb },
      { key: "exercises", label: "Exercises", align: "right", format: formatInteger }
    ], "No workouts match the current filters.");
  }

  function handleFilterChange() {
    refreshLinkedFilters();
    renderDashboard();
  }

  function resetFilters() {
    var start = byId("date-start-filter");
    var end = byId("date-end-filter");
    if (start) {
      start.value = state.minDate;
    }
    if (end) {
      end.value = state.maxDate;
    }
    ["exercise-filter", "movement-filter", "equipment-filter"].forEach(function (id) {
      var select = byId(id);
      if (select) {
        Array.from(select.options).forEach(function (option) {
          option.selected = true;
        });
      }
    });
    refreshLinkedFilters();
    renderDashboard();
  }

  function initializeDates() {
    var dates = uniqueValues(state.rows, "date");
    state.minDate = dates[0] || "";
    state.maxDate = dates[dates.length - 1] || "";

    var start = byId("date-start-filter");
    var end = byId("date-end-filter");
    [start, end].forEach(function (input) {
      if (!input) {
        return;
      }
      input.min = state.minDate;
      input.max = state.maxDate;
    });
    if (start) {
      start.value = state.minDate;
    }
    if (end) {
      end.value = state.maxDate;
    }
  }

  function initializeDashboard() {
    var payload = readPayload();
    state.rows = (payload.rows || []).map(normalizeRow).filter(function (row) {
      return row.date !== "";
    });

    initializeDates();
    refreshLinkedFilters();

    ["date-start-filter", "date-end-filter", "exercise-filter", "movement-filter", "equipment-filter"].forEach(function (id) {
      var element = byId(id);
      if (element) {
        element.addEventListener("change", handleFilterChange);
      }
    });

    var reset = byId("reset-filters");
    if (reset) {
      reset.addEventListener("click", resetFilters);
    }

    renderDashboard();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initializeDashboard);
  } else {
    initializeDashboard();
  }
})();
