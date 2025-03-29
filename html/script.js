document.addEventListener('DOMContentLoaded', function() {
    const scoreboard = document.getElementById('scoreboard');
    const playerList = document.getElementById('player-list');
    const onlineCount = document.getElementById('online-count');
    const scoreboardTitle = document.querySelector('.scoreboard-header h1');
    const body = document.body;
    const scoreboardContent = document.querySelector('.scoreboard-content');

    // Handle NUI messages from the game client
    window.addEventListener('message', function(event) {
        const data = event.data;

        if (data.type === 'showScoreboard') {
            showScoreboard(data.players, data.title, data.position, data.largeMode, data.jobConfigs, data.jobCounts, data.showJobs);
        } else if (data.type === 'hideScoreboard') {
            hideScoreboard();
        } else if (data.type === 'updatePlayers') {
            updatePlayerList(data.players);
            // Update title if provided
            if (data.title && scoreboardTitle) {
                scoreboardTitle.textContent = data.title;
            }
            // Update position and mode if provided
            if (data.position || data.largeMode !== undefined) {
                updateScoreboardLayout(data.position, data.largeMode);
            }
            // Update showJobs setting if provided
            if (data.showJobs !== undefined) {
                scoreboard.dataset.showJobs = data.showJobs;
            }
            // Update job services if jobs should be shown
            if (data.showJobs && data.jobConfigs && data.jobCounts) {
                updateEmergencyServices(data.jobConfigs, data.jobCounts);
            } else {
                // Remove emergency services section if disabled
                const jobServices = document.querySelector('.emergency-services');
                if (jobServices) {
                    jobServices.remove();
                }
            }
        } else if (data.type === 'scroll') {
            handleScroll(data.offset);
        }
    });

    // Function to handle scroll position
    function handleScroll(offset) {
        if (scoreboardContent) {
            // Calculate maximum scroll range
            const maxScroll = scoreboardContent.scrollHeight - scoreboardContent.clientHeight;
            const scrollPos = Math.min(offset * 10, maxScroll); // Multiply by 10 for faster scroll
            scoreboardContent.scrollTop = scrollPos;
        }
    }

    // Function to update emergency services display
    function updateEmergencyServices(jobConfigs, jobCounts) {
        // Find or create job services container
        let jobServices = document.querySelector('.emergency-services');
        
        if (!jobServices) {
            jobServices = document.createElement('div');
            jobServices.className = 'emergency-services';
            
            // Add to scoreboard above content
            const scoreboardHeader = document.querySelector('.scoreboard-header');
            if (scoreboardHeader) {
                scoreboard.insertBefore(jobServices, scoreboardContent);
            }
        }
        
        // Clear previous content
        jobServices.innerHTML = '';
        
        // Create elements for each configured job
        jobConfigs.forEach(job => {
            const count = jobCounts[job.name] || 0;
            
            const jobElement = document.createElement('div');
            jobElement.className = 'emergency-service';
            
            const iconElement = document.createElement('div');
            iconElement.className = 'service-icon';
            iconElement.style.color = job.color;
            iconElement.textContent = job.icon;
            
            const countElement = document.createElement('div');
            countElement.className = 'service-count';
            countElement.textContent = count + ' ' + job.label;
            
            jobElement.appendChild(iconElement);
            jobElement.appendChild(countElement);
            
            jobServices.appendChild(jobElement);
        });
    }

    // Function to update scoreboard position and mode
    function updateScoreboardLayout(position, largeMode) {
        // Remove all position and mode classes
        body.classList.remove('position-left', 'position-center', 'position-right', 'large-mode');
        
        // Apply large mode if enabled (which overrides position)
        if (largeMode) {
            body.classList.add('large-mode');
        } 
        // Otherwise apply position class
        else if (position === 'left' || position === 'right' || position === 'center') {
            body.classList.add(`position-${position}`);
        } else {
            // Default to center if invalid position
            body.classList.add('position-center');
        }
    }

    // Function to show the scoreboard
    function showScoreboard(players, title, position, largeMode, jobConfigs, jobCounts, showJobs) {
        scoreboard.classList.remove('hidden');
        // Set the title if provided
        if (title && scoreboardTitle) {
            scoreboardTitle.textContent = title;
        }
        // Set position and mode if provided
        updateScoreboardLayout(position, largeMode);
        
        // Store the settings as data attributes for later use
        scoreboard.dataset.largeMode = largeMode;
        scoreboard.dataset.showJobs = showJobs;
        
        // Store job configs as stringified JSON if jobs should be shown
        if (showJobs && jobConfigs) {
            scoreboard.dataset.jobConfigs = JSON.stringify(jobConfigs);
        } else {
            delete scoreboard.dataset.jobConfigs;
        }
        
        updatePlayerList(players);
        
        // Show job information in large mode if enabled
        if (largeMode && showJobs && jobConfigs && jobCounts) {
            updateEmergencyServices(jobConfigs, jobCounts);
        } else {
            // Remove emergency services section if disabled
            const jobServices = document.querySelector('.emergency-services');
            if (jobServices) {
                jobServices.remove();
            }
        }
        
        // Update the scoreboard footer with control info
        updateControlsInfo();
    }
    
    // Function to update controls info in footer
    function updateControlsInfo() {
        const footer = document.querySelector('.scoreboard-footer p');
        if (footer) {
            footer.innerHTML = 'Press HOME to close | Arrow keys to scroll';
        }
    }

    // Function to hide the scoreboard
    function hideScoreboard() {
        scoreboard.classList.add('hidden');
    }

    // Function to update the player list
    function updatePlayerList(players) {
        playerList.innerHTML = '';
        
        // Update the online count with correct phrasing
        if (players.length === 1) {
            onlineCount.textContent = `1 Player Online`;
        } else {
            onlineCount.textContent = `${players.length} Players Online`;
        }
        
        // Get stored job configurations
        let jobConfigs = [];
        const showJobs = scoreboard.dataset.showJobs === "true";
        
        if (showJobs && scoreboard.dataset.jobConfigs) {
            try {
                jobConfigs = JSON.parse(scoreboard.dataset.jobConfigs);
            } catch (e) {
                console.error("Failed to parse job configs:", e);
            }
        }
        
        // Check if we're in large mode
        const largeMode = scoreboard.dataset.largeMode === "true";

        players.forEach(player => {
            const playerRow = document.createElement('div');
            playerRow.className = 'player-row';

            const pingClass = getPingClass(player.ping);
            
            // Find job config for this player
            const jobConfig = jobConfigs.find(job => job.name === player.job);
            
            // Create base HTML structure
            let rowHTML = `
                <div class="player-id">${player.id}</div>
                <div class="player-name">`;
            
            // Add player name
            rowHTML += `${player.name}`;
            
            // Add job icon after the name if we have a matching job, not in large mode, and jobs are enabled
            if (showJobs && jobConfig && !largeMode) {
                rowHTML += ` <span class="player-job-icon" style="color: ${jobConfig.color}">${jobConfig.icon}</span>`;
            }
            
            // Complete the HTML
            rowHTML += `</div>
                <div class="player-ping ${pingClass}">${player.ping}</div>
            `;
            
            playerRow.innerHTML = rowHTML;
            playerList.appendChild(playerRow);
        });
    }

    // Function to determine ping class based on value
    function getPingClass(ping) {
        if (ping < 100) {
            return '';  // Default green color from CSS
        } else if (ping < 200) {
            return 'ping-warning';
        } else {
            return 'ping-danger';
        }
    }
}); 