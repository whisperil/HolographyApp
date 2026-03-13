classdef HolographyApp < handle
    properties
        % Hardware and Data
        Camera; FileList; LoopIdx; Mode;
        
        % Algorithm Variables
        Centroid; Step = 400; Range = 80; MaskR = 50;
        R_Range; C_Range;
        
        % GUI Containers
        Fig; ControlPanel; DisplayPanel;
        AxRaw; AxSpec; AxInt; AxPhase;
        HRaw; HSpec; HInt; HPhase;
        
        % Controls
        EditExp; EditRange; DropMode;
        BtnStart; BtnCalib; BtnSave;
        IsRunning = false;
    end
    
    methods
        function obj = HolographyApp()
            obj.setupUI();
        end
        
        function setupUI(obj)
            % Create main window
            obj.Fig = figure('Name', 'Off-axis Digital Holography System', ...
                'NumberTitle', 'off', 'MenuBar', 'none', 'Color', [0.94 0.94 0.94], ...
                'Position', [100, 100, 1300, 850]);
            
            %% === Left Control Panel (20% Width) ===
            obj.ControlPanel = uipanel(obj.Fig, 'Title', 'Control Settings', ...
                'FontSize', 14, 'FontWeight', 'bold', ...
                'Units', 'normalized', 'Position', [0.01 0.02 0.18 0.96], ...
                'BackgroundColor', [1 1 1]);
            
            % Mode Selection
            uicontrol(obj.ControlPanel, 'Style', 'text', 'String', 'Data Source Mode:', 'FontSize', 12, ...
                'Units', 'normalized', 'Position', [0.1 0.92 0.8 0.03], 'HorizontalAlignment', 'left', 'BackgroundColor', 'w');
            obj.DropMode = uicontrol(obj.ControlPanel, 'Style', 'popupmenu', 'String', {'Folder', 'Live'}, ...
                'FontSize', 12, 'Units', 'normalized', 'Position', [0.1 0.88 0.8 0.04]);
            
            % Exposure Time
            uicontrol(obj.ControlPanel, 'Style', 'text', 'String', 'Exposure Time (us):', 'FontSize', 12, ...
                'Units', 'normalized', 'Position', [0.1 0.80 0.8 0.03], 'HorizontalAlignment', 'left', 'BackgroundColor', 'w');
            obj.EditExp = uicontrol(obj.ControlPanel, 'Style', 'edit', 'String', '2000', ...
                'FontSize', 12, 'Units', 'normalized', 'Position', [0.1 0.76 0.8 0.04]);
            
            % Filter Range
            uicontrol(obj.ControlPanel, 'Style', 'text', 'String', 'Filter Range (px):', 'FontSize', 12, ...
                'Units', 'normalized', 'Position', [0.1 0.68 0.8 0.03], 'HorizontalAlignment', 'left', 'BackgroundColor', 'w');
            obj.EditRange = uicontrol(obj.ControlPanel, 'Style', 'edit', 'String', '80', ...
                'FontSize', 12, 'Units', 'normalized', 'Position', [0.1 0.64 0.8 0.04]);
            
            % Action Buttons
            obj.BtnCalib = uicontrol(obj.ControlPanel, 'Style', 'pushbutton', 'String', '1. Auto Calibrate', ...
                'FontSize', 13, 'FontWeight', 'bold', 'Units', 'normalized', 'Position', [0.1 0.45 0.8 0.07], ...
                'Callback', @(~,~)obj.calibrate());
            
            obj.BtnStart = uicontrol(obj.ControlPanel, 'Style', 'pushbutton', 'String', '2. Run System', ...
                'FontSize', 13, 'FontWeight', 'bold', 'Units', 'normalized', 'Position', [0.1 0.35 0.8 0.07], ...
                'BackgroundColor', [0.8 1 0.8], 'Callback', @(~,~)obj.toggleRun());
            
            obj.BtnSave = uicontrol(obj.ControlPanel, 'Style', 'pushbutton', 'String', 'Save Current Field', ...
                'FontSize', 12, 'Units', 'normalized', 'Position', [0.1 0.15 0.8 0.06], ...
                'Callback', @(~,~)obj.saveData());

            %% === Right Display Area (80% Width) ===
            obj.AxRaw = subplot('Position', [0.25 0.55 0.33 0.38]); 
            title('Interferogram', 'FontSize', 14); xlabel('Pixel'); ylabel('Pixel');
            
            obj.AxSpec = subplot('Position', [0.64 0.55 0.33 0.38]); 
            title('FFT Spectrum (Log)', 'FontSize', 14); xlabel('fx'); ylabel('fy');
            
            obj.AxInt = subplot('Position', [0.25 0.08 0.33 0.38]); 
            title('Recovered Intensity', 'FontSize', 14); xlabel('x'); ylabel('y');
            
            obj.AxPhase = subplot('Position', [0.64 0.08 0.33 0.38]); 
            title('Recovered Phase', 'FontSize', 14); xlabel('x'); ylabel('y');
            
            colormap(obj.AxPhase, 'hsv');
        end
        
        function calibrate(obj)
            obj.Mode = obj.DropMode.String{obj.DropMode.Value};
            obj.Range = str2double(obj.EditRange.String);
            if strcmp(obj.Mode, 'Live')
                try
                    if isempty(obj.Camera), obj.Camera = gigecam(1); end
                    obj.Camera.ExposureTime = str2double(obj.EditExp.String);
                    img = double(snapshot(obj.Camera));
                catch
                    errordlg('Camera connection failed.'); return;
                end
            else
                path = uigetdir('.', 'Select Image Folder');
                if path == 0, return; end
                obj.FileList = dir(fullfile(path, '*.tiff'));
                obj.LoopIdx = 1;
                img = im2double(imread(fullfile(path, obj.FileList(1).name)));
            end
            img_mono = img(:,:,1); [rows, cols] = size(img_mono);
            idx_mean = 545; idy_mean = 612; 
            obj.R_Range = max(1, idx_mean-obj.Step):min(rows, idx_mean+obj.Step);
            obj.C_Range = max(1, idy_mean-obj.Step):min(cols, idy_mean+obj.Step);
            crop = img_mono(obj.R_Range, obj.C_Range);
            spec = abs(fftshift(fft2(crop))); [sR, sC] = size(spec);
            cx = round(sR/2); cy = round(sC/2); [X, Y] = meshgrid(1:sC, 1:sR);
            spec_mask = spec; spec_mask(sqrt((X-cy).^2 + (Y-cx).^2) < obj.MaskR) = 0;
            [~, idx] = max(spec_mask(:)); [obj.Centroid(1), obj.Centroid(2)] = ind2sub(size(spec), idx);
            x_axis = (1:sC) - cy; y_axis = (1:sR) - cx;
            obj.HRaw = imagesc(x_axis, y_axis, crop, 'Parent', obj.AxRaw); axis(obj.AxRaw, 'image'); colorbar(obj.AxRaw);
            obj.HSpec = imagesc(x_axis, y_axis, log(1+spec), 'Parent', obj.AxSpec); axis(obj.AxSpec, 'image'); colorbar(obj.AxSpec);
            obj.HInt = imagesc(x_axis, y_axis, zeros(sR, sC), 'Parent', obj.AxInt); axis(obj.AxInt, 'image'); colorbar(obj.AxInt);
            obj.HPhase = imagesc(x_axis, y_axis, zeros(sR, sC), 'Parent', obj.AxPhase); axis(obj.AxPhase, 'image'); colorbar(obj.AxPhase);
            msgbox('Calibration Successful!', 'Info');
        end
        
        function toggleRun(obj)
            if obj.IsRunning
                obj.IsRunning = false; obj.BtnStart.String = '2. Run System'; obj.BtnStart.BackgroundColor = [0.8 1 0.8];
            else
                if isempty(obj.Centroid), errordlg('Please Calibrate first!'); return; end
                obj.IsRunning = true; obj.BtnStart.String = 'Stop System'; obj.BtnStart.BackgroundColor = [1 0.7 0.7];
                obj.runLoop();
            end
        end
        
        function runLoop(obj)
            [sR, sC] = size(obj.HRaw.CData); cx = round(sR/2); cy = round(sC/2);
            [fx, fy] = meshgrid(-obj.Range:obj.Range, -obj.Range:obj.Range);
            dist = sqrt(fx.^2 + fy.^2); win = (1 + cos(pi * dist / obj.Range)) / 2; win(dist > obj.Range) = 0;
            while obj.IsRunning && ishandle(obj.Fig)
                if strcmp(obj.Mode, 'Live'), img = double(snapshot(obj.Camera));
                else
                    if obj.LoopIdx > length(obj.FileList), obj.IsRunning = false; break; end
                    img = im2double(imread(fullfile(obj.FileList(obj.LoopIdx).folder, obj.FileList(obj.LoopIdx).name)));
                    obj.LoopIdx = obj.LoopIdx + 1;
                end
                crop = img(obj.R_Range, obj.C_Range, 1); B_fft = fftshift(fft2(crop));
                Level1 = zeros(sR, sC); r_idx = (obj.Centroid(1)-obj.Range):(obj.Centroid(1)+obj.Range);
                c_idx = (obj.Centroid(2)-obj.Range):(obj.Centroid(2)+obj.Range);
                Level1((cx-obj.Range):(cx+obj.Range), (cy-obj.Range):(cy+obj.Range)) = B_fft(r_idx, c_idx) .* win;
                Beam = ifft2(ifftshift(Level1));
                set(obj.HRaw, 'CData', crop);
                set(obj.HSpec, 'CData', log(1 + abs(B_fft)));
                set(obj.HInt, 'CData', abs(Beam).^2);
                set(obj.HPhase, 'CData', angle(Beam));
                drawnow limitrate;
            end
        end
        
        function saveData(obj)
            if isempty(obj.HInt), return; end
            Amp = sqrt(obj.HInt.CData); Phase = obj.HPhase.CData;
            ComplexField = Amp .* exp(1i * Phase);
            fname = ['Result_', datestr(now, 'yyyymmdd_HHMMSS'), '.mat'];
            save(fname, 'ComplexField');
            msgbox(['File saved as: ', fname], 'Success');
        end
    end
end