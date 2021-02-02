classdef Model < handle
    %MODEL MVC Model class for tbNewToolbox()
    %
    %  SEE ALSO tbnewtoolbox.View, tbnewtoolbox.Controller
    %
    %  2021 Markus Leuthold markus.leuthold@sonova.com
    
    properties
        toolboxNames
        prefs
        subfolder
    end
    
    methods(Access = private)
        function s = getToolboxesString(~, toolboxNames)
            assert(iscell(toolboxNames))
            if length(toolboxNames) == 1
                s = ['''' toolboxNames{1} ''''];
            else
                x = join(toolboxNames, ''', ''');
                s = ['{''' x{1} '''}'];
            end
        end
    end
    
    methods
        function self = Model
            [~, self.toolboxNames] = tbGetToolboxNames;
            self.prefs = tbParsePrefs(tbGetPersistentPrefs);
        end
        
        function tn = getNewToolboxName(self)
            gitRoot = self.getGitRoot;
            if isempty(gitRoot)
                % no git exist yet, assume this is the root dir for a
                % future git repo
                gitRoot = pwd;
            end
            
            tn = self.getCurrentToolboxName(gitRoot);
        end
        
        function checkHubInstallation(~)
            cmd = 'hub --version';
            [~, out] = system(cmd);
            assert(contains(out, 'hub version'), 'tbtb:HubNotFound', ...
                'Cannot find hub. Please install from <a href="https://github.com/github/hub#installation">Github</a>.')
        end
        
        function createLocalGitRepo(~)
            cmd = 'git init';
            system(cmd)
        end
        
        function url = createRemoteGitRepo(self, shortDescription)
            self.checkHubInstallation
            cmd = ['hub create -d "' shortDescription '"'];
            [tf, out] = system(cmd);
            assert(tf == 0, """hub create"" failed" + newline + out)
            lines = split(strip(out));
            url = lines{end};
        end
        
        function toolboxName = getCurrentToolboxName(~, currentRoot)
            toolboxRoot = strrep(tbGetPersistentPrefs().toolboxRoot, '\', '/');
            toolboxName = erase(strrep(currentRoot, '\', '/'), toolboxRoot);
            
            % delete leading slash
            toolboxName = regexprep(toolboxName, '^/', '');
        end
        
        function gitRoot = getGitRoot(~)
            [retVal, out] = system('git rev-parse --show-toplevel');
            if retVal == 0
                gitRoot = strip(out);
            else
                gitRoot = [];
            end
        end
        
        function wellFormedRecord = getMainRecord(~, toolboxName, url, subfolder, pathPlacement)
            record.name = toolboxName;
            record.subfolder = subfolder;
            record.type = 'git';
            record.url = url;
            record.pathPlacement = pathPlacement;
            %             record.cdToFolder = self.cdToFolderEditField.Value;
            wellFormedRecord = tbToolboxRecord(record);
        end
        
        function wellFormedRecords = getDependencyRecords(~, dependencies)
            wellFormedRecords = tbToolboxRecord;
            for k = 1:length(dependencies)
                record.name = strrep(dependencies{k}, '\', '/');
                record.type = 'include';
                wellFormedRecords(k) = tbToolboxRecord(record, 'pathPlacement', '');
            end
        end
        
        function records = getRecords(self, toolboxName, url, subfolder, dependencies)
            mainRecord = self.getMainRecord(toolboxName, url, subfolder);
            dependencyRecords = self.getDependencyRecords(dependencies);
            records = [mainRecord, dependencyRecords];
        end
        
        function filePath = getConfigFilePath(~, toolboxName)
            prefs = tbParsePrefs(tbGetPersistentPrefs);
            registryRoot = tbLocateToolbox(prefs.registry);
            configRoot = fullfile(registryRoot, prefs.registry.subfolder);
            [~, configDirs] = fileparts(toolboxName);
            folder = fullfile(configRoot, configDirs);
            if ~isfolder(folder)
                mkdir(folder)
            end
            filePath = fullfile(configRoot, [toolboxName '.json']);
        end
        
        function writeRecords(~, records, filePath)
            % create subfolders if needed
            subfolder = fileparts(filePath);
            if ~isfolder(subfolder)
                disp(subfolder + " doesn't exist, create folder");
                mkdir(subfolder);
            end
            disp("write config file to " + filePath)
            savejson('', records, filePath)
        end
        
        function createToolbox(self, shortDescription, subfolder, dependencies)
            gitRoot = self.getGitRoot;
            if isempty(gitRoot)
                disp("No git repo exists in current folder, create a new one")
                self.createLocalGitRepo
                gitRoot = pwd;
            end
            
            url = self.createRemoteGitRepo(shortDescription);
            toolboxName = self.getCurrentToolboxName(gitRoot);
            records = self.getRecords(toolboxName, url, subfolder, dependencies);
            filePath = self.getConfigFilePath(toolboxName);
            self.writeRecords(records, filePath)
        end
        
        function filteredToolboxNames = filterToolboxes(self, filterStr)
            if isempty(filterStr)
                % If filter string is empty, e.g after clearing the filter
                % edit box, the user most likely wants to see everything
                filterStr = '.*';
            end
            idx = ~cellfun(@isempty, regexpi(self.toolboxNames, filterStr));
            filteredToolboxNames = self.toolboxNames(idx);
        end
    end
end

