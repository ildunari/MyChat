This file is a merged representation of the entire codebase, combined into a single document by Repomix.

================================================================
File Summary
================================================================

Purpose:
--------
This file contains a packed representation of the entire repository's contents.
It is designed to be easily consumable by AI systems for analysis, code review,
or other automated processes.

File Format:
------------
The content is organized as follows:
1. This summary section
2. Repository information
3. Directory structure
4. Multiple file entries, each consisting of:
  a. A separator line (================)
  b. The file path (File: path/to/file)
  c. Another separator line
  d. The full contents of the file
  e. A blank line

Usage Guidelines:
-----------------
- This file should be treated as read-only. Any changes should be made to the
  original repository files, not this packed version.
- When processing this file, use the file path to distinguish
  between different files in the repository.
- Be aware that this file may contain sensitive information. Handle it with
  the same level of security as you would the original repository.

Notes:
------
- Some files may have been excluded based on .gitignore rules and Repomix's configuration
- Binary files are not included in this packed representation. Please refer to the Repository Structure section for a complete list of file paths, including binary files
- Files matching patterns in .gitignore are excluded
- Files matching default ignore patterns are excluded

Additional Info:
----------------

================================================================
Directory Structure
================================================================
components/
  ControlPanel.tsx
  DockingLayout.tsx
  DragGhost.tsx
  DropZoneOverlay.tsx
  ErrorBoundary.tsx
  FocusedView.tsx
  FullScreenImageViewer.tsx
  HistoryViewer.tsx
  Icons.tsx
  ImageTree.tsx
  ImageViewer.tsx
  Loader.tsx
  Panel.tsx
  PanelDropZone.tsx
  PromptDiffViewer.tsx
  Sash.tsx
  SelectedImagesTray.tsx
  SettingsModal.tsx
hooks/
  useMediaQuery.ts
  useResizeObserver.ts
scripts/
  dev-tailscale.sh
services/
  geminiService.ts
utils/
  imageUtils.ts
  layoutUtils.ts
.gitignore
AGENTS.md
App.tsx
index.html
index.tsx
metadata.json
package.json
README.md
tsconfig.json
types.ts
vite.config.ts

================================================================
Files
================================================================

================
File: components/ControlPanel.tsx
================
import React, { useState, useRef, useEffect } from 'react';
import { ImageNode } from '../types';
import { UploadIcon, SparklesIcon, CogIcon, CursorArrowRaysIcon, PaperClipIcon, ArrowUturnLeftIcon } from './Icons';
import SelectedImagesTray from './SelectedImagesTray';
import { enhancePrompt } from '../services/geminiService';
import PromptDiffViewer from './PromptDiffViewer';
import { toast } from 'react-toastify';

interface ControlPanelProps {
    onGenerate: (prompt: string, numVariations: number, useAIVariations: boolean, variationLevel: number, aspectRatio: string) => void;
    onInitialImageUpload: (file: File) => void;
    onAddNewImage: (file: File) => void;
    hasImage: boolean;
    selectedNodes: ImageNode[];
    onRemoveSelectedNode: (nodeId: string) => void;
    onViewNode: (node: ImageNode) => void;
    isSelectMode: boolean;
    setIsSelectMode: (isSelectMode: boolean) => void;
    onOpenSettings: () => void;
    isGenerating: boolean;
}

const dataUrlToBase64 = (dataUrl: string): { data: string, mimeType: string } => {
    const parts = dataUrl.split(',');
    const mimeType = parts[0].match(/:(.*?);/)?.[1] || 'image/png';
    const data = parts[1];
    return { data, mimeType };
};

const aspectRatioOptions = [
    { value: 'auto', label: 'Auto' },
    { value: '1:1', label: '1:1' },
    { value: '16:9', label: '16:9' },
    { value: '9:16', label: '9:16' },
    { value: '3:2', label: '3:2' },
    { value: '2:3', label: '2:3' },
];


const ControlPanel: React.FC<ControlPanelProps> = ({
    onGenerate,
    onInitialImageUpload,
    onAddNewImage,
    hasImage,
    selectedNodes,
    onRemoveSelectedNode,
    onViewNode,
    isSelectMode,
    setIsSelectMode,
    onOpenSettings,
    isGenerating,
}) => {
    const [prompt, setPrompt] = useState<string>('');
    const [numVariations, setNumVariations] = useState<number>(5);
    const [useAIVariations, setUseAIVariations] = useState<boolean>(true);
    const [variationLevel, setVariationLevel] = useState<number>(3);
    const [aspectRatio, setAspectRatio] = useState('auto');
    const formRef = useRef<HTMLFormElement>(null);
    const textareaRef = useRef<HTMLTextAreaElement>(null);
    
    const [promptDiff, setPromptDiff] = useState<{old: string, new: string} | null>(null);
    const [isEnhancing, setIsEnhancing] = useState(false);
    const [includeImagesForEnhance, setIncludeImagesForEnhance] = useState(true);

    const [isDraggingOver, setIsDraggingOver] = useState(false);

    // Auto-detect aspect ratio from selected image
    useEffect(() => {
        if (selectedNodes.length === 1) {
            const img = new Image();
            img.onload = () => {
                const w = img.naturalWidth;
                const h = img.naturalHeight;
                if (w === 0 || h === 0) {
                    setAspectRatio('auto');
                    return;
                }
                const r = w / h;
    
                const ratios = [
                    { val: '1:1', ratio: 1 },
                    { val: '16:9', ratio: 16 / 9 },
                    { val: '9:16', ratio: 9 / 16 },
                    { val: '3:2', ratio: 3 / 2 },
                    { val: '2:3', ratio: 2 / 3 },
                ];
    
                let closest = ratios[0];
                let minDiff = Math.abs(r - closest.ratio);
    
                for (let i = 1; i < ratios.length; i++) {
                    const diff = Math.abs(r - ratios[i].ratio);
                    if (diff < minDiff) {
                        minDiff = diff;
                        closest = ratios[i];
                    }
                }
                
                // Set if reasonably close (e.g., within 5% of the target ratio)
                if (minDiff / r < 0.05) {
                    setAspectRatio(closest.val);
                } else {
                    setAspectRatio('auto');
                }
            };
            img.onerror = () => {
                setAspectRatio('auto');
            };
            img.src = selectedNodes[0].imageUrl;
        } else {
            setAspectRatio('auto');
        }
    }, [selectedNodes]);

    // Auto-clear diff on new input
    useEffect(() => {
        if (promptDiff) {
            const timer = setTimeout(() => {
                setPromptDiff(null);
            }, 5000); // Clear after 5 seconds of inactivity
            return () => clearTimeout(timer);
        }
    }, [prompt, promptDiff]);

    const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        const file = event.target.files?.[0];
        if (file) {
            onInitialImageUpload(file);
        }
    };
    
    const handleAddNewFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        const file = event.target.files?.[0];
        if (file) {
            onAddNewImage(file);
        }
         event.target.value = ''; // Reset file input
    };

    const handleSubmit = (event: React.FormEvent) => {
        event.preventDefault();
        if (isGenerating || selectedNodes.length === 0) {
            return;
        }
        onGenerate(prompt, numVariations, useAIVariations, variationLevel, aspectRatio);
    };

    const handleKeyDown = (event: React.KeyboardEvent<HTMLTextAreaElement>) => {
        if (event.key === 'Enter' && event.shiftKey) {
            event.preventDefault();
            if (!isGenerating) {
                formRef.current?.requestSubmit();
            }
        }
    };

    const handleEnhancePrompt = async () => {
        if (!prompt.trim() && selectedNodes.length === 0) {
            toast.warn("Please provide a prompt or select an image to enhance.");
            return;
        }

        setIsEnhancing(true);
        const originalPrompt = prompt;
        
        const imagesToInclude = (includeImagesForEnhance && selectedNodes.length > 0)
            ? selectedNodes.map(n => dataUrlToBase64(n.imageUrl))
            : [];

        try {
            const enhanced = await enhancePrompt(prompt, imagesToInclude);
            setPrompt(enhanced);
            setPromptDiff({ old: originalPrompt, new: enhanced });
        } catch (e: any) {
            toast.error(e.message || "An error occurred while enhancing the prompt.");
            console.error("Enhance prompt error:", e);
        } finally {
            setIsEnhancing(false);
        }
    };

    const handleRevertPrompt = () => {
        if (promptDiff) {
            setPrompt(promptDiff.old);
            setPromptDiff(null);
        }
    };

    // Drag and drop handlers for initial upload
    const handleDragOver = (e: React.DragEvent) => {
        e.preventDefault();
        e.stopPropagation();
    };

    const handleDragEnter = (e: React.DragEvent) => {
        e.preventDefault();
        e.stopPropagation();
        setIsDraggingOver(true);
    };

    const handleDragLeave = (e: React.DragEvent) => {
        e.preventDefault();
        e.stopPropagation();
        setIsDraggingOver(false);
    };

    const handleDrop = (e: React.DragEvent) => {
        e.preventDefault();
        e.stopPropagation();
        setIsDraggingOver(false);
        if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
            const file = e.dataTransfer.files[0];
            if (file.type.startsWith('image/')) {
                onInitialImageUpload(file);
            } else {
                toast.error("Please drop an image file.");
            }
            e.dataTransfer.clearData();
        }
    };

    const renderOptions = () => (
        <>
            <div className="p-3 bg-gray-700/50 rounded-lg space-y-3">
                <SelectedImagesTray selectedNodes={selectedNodes} onRemove={onRemoveSelectedNode} onView={onViewNode} />
                 <button
                    type="button"
                    onClick={() => setIsSelectMode(!isSelectMode)}
                    className={`w-full flex items-center justify-center px-4 py-2 border rounded-md text-sm font-medium transition-colors btn-press-feedback ${isSelectMode
                            ? 'bg-blue-600 border-blue-500 text-white'
                            : 'bg-gray-700 border-gray-600 hover:bg-gray-600 text-gray-300'
                        }`}
                >
                    <CursorArrowRaysIcon className="w-5 h-5 mr-2" />
                    {isSelectMode ? 'Multi-Select Active' : 'Enable Multi-Select'}
                </button>
            </div>
            
            <div className="p-3 bg-gray-700/50 rounded-lg space-y-4">
                 <div>
                    <label htmlFor="variations" className="block text-sm font-medium text-gray-300">
                        Variations ({numVariations})
                    </label>
                    <input
                        id="variations"
                        type="range"
                        min="1"
                        max="10"
                        value={numVariations}
                        onChange={(e) => setNumVariations(Number(e.target.value))}
                        className="w-full h-2 bg-gray-600 rounded-lg appearance-none cursor-pointer accent-teal-500"
                    />
                </div>
            </div>

            <div className="bg-gray-700/50 p-3 rounded-lg space-y-3">
                <div className="flex items-center justify-between">
                    <div className="flex items-center">
                        <SparklesIcon className="w-5 h-5 text-yellow-400 mr-2" />
                        <span className="text-sm font-medium text-gray-300">AI Prompt Variations</span>
                    </div>
                    <button
                        type="button"
                        onClick={() => setUseAIVariations(!useAIVariations)}
                        className={`${useAIVariations ? 'bg-teal-600' : 'bg-gray-600'
                            } relative inline-flex items-center h-6 rounded-full w-11 transition-colors`}
                    >
                        <span className={`${useAIVariations ? 'translate-x-6' : 'translate-x-1'
                            } inline-block w-4 h-4 transform bg-white rounded-full transition-transform`} />
                    </button>
                </div>
                {useAIVariations && (
                    <div>
                        <label htmlFor="creativity" className="block text-xs font-medium text-gray-400">
                            Creativity ({variationLevel})
                        </label>
                        <input
                            id="creativity"
                            type="range"
                            min="1"
                            max="5"
                            step="1"
                            value={variationLevel}
                            onChange={(e) => setVariationLevel(Number(e.target.value))}
                            className="w-full h-2 bg-gray-600 rounded-lg appearance-none cursor-pointer accent-yellow-500"
                        />
                    </div>
                )}
            </div>
             <div className="p-3 bg-gray-700/50 rounded-lg space-y-2">
                <label className="block text-sm font-medium text-gray-300">
                    Aspect Ratio
                </label>
                <div className="grid grid-cols-3 gap-2">
                    {aspectRatioOptions.map(({ value, label }) => (
                        <button
                            key={value}
                            type="button"
                            onClick={() => setAspectRatio(value)}
                            className={`px-2 py-1.5 text-xs font-medium rounded-md transition-colors btn-press-feedback ${
                                aspectRatio === value
                                    ? 'bg-teal-600 text-white shadow-md'
                                    : 'bg-gray-700 hover:bg-gray-600 text-gray-300'
                            }`}
                        >
                            {label}
                        </button>
                    ))}
                </div>
                <p className="text-xs text-gray-400 pt-1">
                    Aspect ratio is provided as a hint to the model. Results may vary.
                </p>
            </div>
        </>
    );

    return (
        <div className="absolute inset-0 flex flex-col bg-gray-800/50">

            {!hasImage ? (
                <div 
                    onDragEnter={handleDragEnter}
                    onDragLeave={handleDragLeave}
                    onDragOver={handleDragOver}
                    onDrop={handleDrop}
                    className={`flex-1 flex flex-col items-center justify-center bg-gray-700/50 rounded-lg border-2 border-dashed border-gray-600 p-4 text-center m-2 overflow-y-auto transition-all ${isDraggingOver ? 'drop-zone-active' : ''}`}
                >
                    <UploadIcon className="w-10 h-10 mx-auto text-gray-500 flex-shrink-0" />
                    {isDraggingOver ? (
                        <p className="mt-3 text-lg font-semibold text-teal-300">Drop your image here</p>
                    ) : (
                        <>
                            <label htmlFor="file-upload" className="mt-3 cursor-pointer bg-teal-600 hover:bg-teal-700 text-white font-bold py-2 px-4 rounded-lg transition-colors btn-press-feedback">
                                Upload Starting Image
                            </label>
                            <input id="file-upload" type="file" className="hidden" accept="image/*" onChange={handleFileChange} />
                            <p className="mt-2 text-sm text-gray-400">or drag and drop it here</p>
                        </>
                    )}
                </div>
            ) : (
                <form ref={formRef} onSubmit={handleSubmit} className="flex flex-col flex-1 overflow-hidden">
                    {/* Generate Button on top */}
                    <div className="p-4 flex-shrink-0 border-b border-gray-700/50">
                        <div className="flex items-center gap-3">
                            <button
                                type="submit"
                                className={`flex-1 bg-gradient-to-r from-teal-500 to-cyan-600 hover:from-teal-600 hover:to-cyan-700 text-white font-bold py-3 px-4 rounded-lg transition-all shadow-lg disabled:opacity-50 disabled:cursor-not-allowed btn-press-feedback ${isGenerating ? 'generate-busy' : ''}`}
                                disabled={selectedNodes.length === 0 || isGenerating}
                                aria-live="polite"
                                aria-busy={isGenerating}
                            >
                                <span className="flex items-center justify-center gap-2">
                                    {isGenerating && <span className="generate-spinner" aria-hidden="true" />}
                                    <span>{isGenerating ? 'Generating…' : 'Generate'}</span>
                                </span>
                            </button>
                            {hasImage && (
                                <>
                                    <input id="add-new-image-upload" type="file" className="hidden" accept="image/*" onChange={handleAddNewFileChange} />
                                    <label
                                        htmlFor="add-new-image-upload"
                                        className="p-2 text-gray-300 hover:text-white hover:bg-gray-700 rounded-full transition-colors cursor-pointer btn-press-feedback"
                                        title="Import image"
                                    >
                                        <PaperClipIcon className="w-6 h-6" />
                                    </label>
                                </>
                            )}
                            <button
                                type="button"
                                onClick={onOpenSettings}
                                className="p-2 text-gray-300 hover:text-white hover:bg-gray-700 rounded-full transition-colors btn-press-feedback"
                                title="Settings"
                            >
                                <CogIcon className="w-6 h-6" />
                            </button>
                        </div>
                    </div>
                    {/* Main scrollable content area */}
                    <div className="flex-1 p-4 overflow-y-auto space-y-4">
                        <div className="p-3 bg-gray-700/50 rounded-lg">
                            <label htmlFor="prompt-desktop" className="block text-sm font-medium text-gray-300 mb-1">
                                Your Creative Prompt (Shift+Enter)
                            </label>
                            <div className="relative">
                                {promptDiff && (
                                    <PromptDiffViewer oldText={promptDiff.old} newText={promptDiff.new} />
                                )}
                                <textarea
                                    ref={textareaRef}
                                    id="prompt-desktop"
                                    rows={4}
                                    className={`w-full bg-gray-700/80 border border-gray-600 rounded-lg p-2 text-white text-base focus:ring-2 focus:ring-teal-500 focus:border-teal-500 transition 
                                        ${isEnhancing ? 'prompt-enhancing' : ''}
                                        ${promptDiff ? 'bg-transparent text-transparent caret-white' : ''}
                                    `}
                                    value={prompt}
                                    onChange={(e) => {
                                        setPrompt(e.target.value);
                                        if (promptDiff) setPromptDiff(null);
                                    }}
                                    onKeyDown={handleKeyDown}
                                    placeholder="e.g., a cat wearing a tiny wizard hat..."
                                />
                            </div>
                             <div className="mt-2 flex items-center justify-between gap-2">
                                <label htmlFor="include-images-enhance" className="flex items-center gap-2 cursor-pointer group">
                                    <input 
                                        type="checkbox" 
                                        id="include-images-enhance"
                                        checked={includeImagesForEnhance}
                                        onChange={(e) => setIncludeImagesForEnhance(e.target.checked)}
                                        disabled={selectedNodes.length === 0 || isEnhancing || isGenerating}
                                        className="w-4 h-4 rounded text-teal-600 bg-gray-700 border-gray-600 focus:ring-teal-500 disabled:opacity-50 disabled:cursor-not-allowed"
                                    />
                                    <span 
                                        className={`text-xs text-gray-400 group-hover:text-gray-200 transition-colors ${selectedNodes.length === 0 ? 'opacity-50' : ''}`}
                                    >
                                        Include Images
                                    </span>
                                </label>
                                
                                <div className="flex items-center gap-2">
                                    {promptDiff && !isEnhancing && (
                                        <button
                                            type="button"
                                            onClick={handleRevertPrompt}
                                            className="p-2 text-gray-400 hover:text-white hover:bg-gray-600 rounded-full transition-colors btn-press-feedback"
                                            title="Revert prompt"
                                        >
                                            <ArrowUturnLeftIcon className="w-5 h-5" />
                                        </button>
                                    )}
                                    <button
                                        type="button"
                                        onClick={handleEnhancePrompt}
                                        className="flex items-center gap-1.5 px-3 py-1.5 bg-yellow-600/80 hover:bg-yellow-600 text-white text-xs font-semibold rounded-md transition-colors disabled:opacity-50 disabled:cursor-not-allowed btn-press-feedback"
                                        disabled={isEnhancing || isGenerating || (!prompt.trim() && selectedNodes.length === 0)}
                                    >
                                        <SparklesIcon className={`w-4 h-4 ${isEnhancing ? 'icon-thinking' : ''}`} />
                                        {isEnhancing ? 'Enhancing...' : 'Enhance Prompt'}
                                    </button>
                                </div>
                            </div>
                        </div>
                        {renderOptions()}
                    </div>
                </form>
            )}
        </div>
    );
};

export default ControlPanel;

================
File: components/DockingLayout.tsx
================
import React, { useRef } from 'react';
import { Layout, SplitContainer } from '../types';
import Sash from './Sash';

interface DockingLayoutProps {
  layout: Layout;
  onLayoutChange: (newLayout: Layout) => void;
  renderPanel: (panelLayout: Layout) => React.ReactNode;
}

const DockingLayout: React.FC<DockingLayoutProps> = ({ layout, onLayoutChange, renderPanel }) => {
  const containerRef = useRef<HTMLDivElement>(null);
  
  if (layout.type === 'panel') {
    return <div className="w-full h-full p-1">{renderPanel(layout)}</div>;
  }

  const handleDrag = (delta: number) => {
    if (!containerRef.current) return;
    const containerSize = layout.direction === 'horizontal' 
      ? containerRef.current.clientWidth 
      : containerRef.current.clientHeight;
      
    if (containerSize === 0) return;

    const deltaPercent = (delta / containerSize) * 100;
    const oldSizes = layout.sizes;

    let newSize1 = oldSizes[0] + deltaPercent;
    let newSize2 = oldSizes[1] - deltaPercent;
    
    const minSize = 5;
    if (newSize1 < minSize) {
        newSize1 = minSize;
        newSize2 = 100 - minSize;
    }
    if (newSize2 < minSize) {
        newSize2 = minSize;
        newSize1 = 100 - minSize;
    }

    const newLayout: SplitContainer = {
      ...layout,
      sizes: [newSize1, newSize2],
    };
    onLayoutChange(newLayout);
  };
  
  const flexDirection = layout.direction === 'horizontal' ? 'row' : 'column';

  return (
    <div ref={containerRef} className="w-full h-full flex" style={{ flexDirection }}>
      <div style={{ flex: `0 0 ${layout.sizes[0]}%` }} className="relative min-w-0 min-h-0">
         <DockingLayout layout={layout.children[0]} onLayoutChange={(newChildLayout) => {
             onLayoutChange({ ...layout, children: [newChildLayout, layout.children[1]] });
         }} renderPanel={renderPanel} />
      </div>
      <Sash direction={layout.direction} onDrag={handleDrag} />
      <div style={{ flex: `1 1 ${layout.sizes[1]}%` }} className="relative min-w-0 min-h-0">
          <DockingLayout layout={layout.children[1]} onLayoutChange={(newChildLayout) => {
             onLayoutChange({ ...layout, children: [layout.children[0], newChildLayout] });
         }} renderPanel={renderPanel} />
      </div>
    </div>
  );
};

export default DockingLayout;

================
File: components/DragGhost.tsx
================
import React from 'react';
import { PanelContent } from '../types';

interface DragGhostProps {
  content: PanelContent;
  position: { x: number; y: number };
}

const contentTitles: Record<PanelContent, string> = {
  tree: 'Node Diagram',
  controls: 'Controls',
  viewer: 'Image Viewer',
};

const DragGhost: React.FC<DragGhostProps> = ({ content, position }) => {
  return (
    <div
      className="fixed top-0 left-0 bg-gray-700/80 border border-teal-500 rounded-md shadow-2xl text-white text-sm px-4 py-2 pointer-events-none z-50"
      style={{
        transform: `translate(${position.x}px, ${position.y}px)`,
      }}
    >
      {contentTitles[content]}
    </div>
  );
};

export default DragGhost;

================
File: components/DropZoneOverlay.tsx
================
import React from 'react';
import { UploadIcon } from './Icons';

const DropZoneOverlay: React.FC = () => {
    return (
        <div className="fixed inset-0 bg-black/70 flex flex-col items-center justify-center z-50 backdrop-blur-sm pointer-events-none">
            <div className="flex flex-col items-center justify-center p-10 border-4 border-dashed border-teal-400 rounded-2xl">
                <UploadIcon className="w-20 h-20 text-teal-300" />
                <p className="mt-4 text-2xl font-bold text-white">
                    Drop image to create a new root node
                </p>
            </div>
        </div>
    );
};

export default DropZoneOverlay;

================
File: components/ErrorBoundary.tsx
================
import React from 'react';

interface ErrorBoundaryProps {
  name?: string;
  fallback?: React.ReactNode;
  children: React.ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
  error?: Error;
}

export default class ErrorBoundary extends React.Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo): void {
    // eslint-disable-next-line no-console
    console.error(`ErrorBoundary(${this.props.name || 'Component'})`, error, info);
  }

  handleReload = () => {
    window.location.reload();
  };

  handleClearLayout = () => {
    try { localStorage.removeItem('imageTreePositions'); } catch {}
    this.handleReload();
  };

  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? (
        <div className="w-full h-full flex items-center justify-center bg-gray-900/80 text-gray-200 p-6">
          <div className="max-w-md text-center">
            <h2 className="text-lg font-semibold mb-2">Something went wrong in {this.props.name || 'this panel'}.</h2>
            <p className="text-sm text-gray-400 mb-4">Try reloading the panel. If it persists, clear the layout cache.</p>
            <div className="flex items-center justify-center gap-3">
              <button onClick={this.handleReload} className="px-3 py-1.5 text-sm rounded bg-gray-800 border border-gray-600 hover:bg-gray-700">Reload</button>
              <button onClick={this.handleClearLayout} className="px-3 py-1.5 text-sm rounded bg-red-700 border border-red-600 hover:bg-red-600">Clear Layout</button>
            </div>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}

================
File: components/FocusedView.tsx
================
import React from 'react';
import { ImageNode } from '../types';
import { TrashIcon, HistoryIcon } from './Icons';

interface FocusedViewProps {
    node: ImageNode | undefined;
    onDelete: (node: ImageNode) => void;
    onShowHistory: (node: ImageNode) => void;
}

const FocusedView: React.FC<FocusedViewProps> = ({ node, onDelete, onShowHistory }) => {
    if (!node) {
        return (
            <div className="w-full h-full flex items-center justify-center bg-black/20 rounded-lg">
                <p className="text-gray-500">Select a node in the tree to view it here.</p>
            </div>
        );
    }

    return (
        <div className="w-full h-full flex flex-col items-center justify-center p-4 relative group">
            <img
                src={node.imageUrl}
                alt={node.prompt}
                className="max-w-full max-h-full object-contain rounded-lg shadow-2xl"
            />
            <div className="absolute bottom-4 left-4 right-4 bg-black/60 backdrop-blur-sm p-2 rounded-md">
                <p className="text-xs text-gray-400 font-mono line-clamp-2">{node.prompt}</p>
            </div>
             <div className="absolute top-4 right-4 flex flex-col gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                <button
                    onClick={() => onDelete(node)}
                    className="p-2 bg-black/50 hover:bg-red-600 text-white rounded-full transition-colors"
                    aria-label="Delete node"
                >
                    <TrashIcon className="w-5 h-5"/>
                </button>
                <button
                    onClick={() => onShowHistory(node)}
                    className="p-2 bg-black/50 hover:bg-blue-600 text-white rounded-full transition-colors"
                    aria-label="Show image history"
                >
                    <HistoryIcon className="w-5 h-5"/>
                </button>
            </div>
        </div>
    );
};

export default FocusedView;

================
File: components/FullScreenImageViewer.tsx
================
import React, { useMemo } from 'react';
import { ImageNode } from '../types';
import { XIcon, PlusCircleIcon, CheckCircleIcon, HistoryIcon, TrashIcon, ChevronLeftIcon, ChevronRightIcon } from './Icons';
import { motion } from 'framer-motion';

interface FullScreenImageViewerProps {
    node: ImageNode;
    onClose: () => void;
    isSelected: boolean;
    onToggleSelect: () => void;
    onShowHistory: (node: ImageNode) => void;
    onDelete: (node: ImageNode) => void;
    carouselNodes: ImageNode[];
    onNavigate: (node: ImageNode) => void;
}

const FullScreenImageViewer: React.FC<FullScreenImageViewerProps> = ({ 
    node, 
    onClose, 
    isSelected, 
    onToggleSelect, 
    onShowHistory,
    onDelete,
    carouselNodes,
    onNavigate
}) => {

    const currentIndex = useMemo(() => {
        return carouselNodes.findIndex(n => n.id === node.id);
    }, [carouselNodes, node.id]);

    const handlePrev = () => {
        if (currentIndex > 0) {
            onNavigate(carouselNodes[currentIndex - 1]);
        }
    };

    const handleNext = () => {
        if (currentIndex < carouselNodes.length - 1) {
            onNavigate(carouselNodes[currentIndex + 1]);
        }
    };

    return (
        <motion.div 
            className="fixed inset-0 bg-black/90 flex items-center justify-center z-50 backdrop-blur-md"
            onClick={onClose}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.3 }}
            role="dialog"
            aria-modal="true"
        >
            <div className="relative w-full h-full p-4 md:p-8 flex items-center justify-center" onClick={e => e.stopPropagation()}>
                <img
                    src={node.imageUrl}
                    alt={node.prompt}
                    className="max-w-full max-h-full object-contain rounded-lg shadow-2xl"
                    fetchPriority="high"
                />
            </div>
            
            <div className="absolute top-4 right-4 flex items-center gap-2">
                 <button
                    onClick={() => onDelete(node)}
                    className="p-2 bg-black/50 hover:bg-red-600 text-white rounded-full transition-colors btn-press-feedback"
                    aria-label="Delete node"
                >
                    <TrashIcon className="w-6 h-6"/>
                </button>
                <button
                    onClick={() => onShowHistory(node)}
                    className="p-2 bg-black/50 hover:bg-gray-700 text-white rounded-full transition-colors btn-press-feedback"
                    aria-label="Show image history"
                >
                    <HistoryIcon className="w-6 h-6"/>
                </button>
                <button
                    onClick={onClose}
                    className="p-2 bg-black/50 hover:bg-gray-700 text-white rounded-full transition-colors btn-press-feedback"
                    aria-label="Close viewer"
                >
                    <XIcon className="w-6 h-6"/>
                </button>
            </div>

            {/* Carousel Navigation */}
            {carouselNodes.length > 1 && (
                <>
                    <button 
                        onClick={handlePrev} 
                        disabled={currentIndex <= 0}
                        className="absolute left-4 top-1/2 -translate-y-1/2 p-2 bg-black/50 text-white rounded-full transition-opacity hover:bg-gray-700 disabled:opacity-30 disabled:cursor-not-allowed btn-press-feedback"
                        aria-label="Previous image"
                    >
                        <ChevronLeftIcon className="w-8 h-8" />
                    </button>
                     <button 
                        onClick={handleNext} 
                        disabled={currentIndex >= carouselNodes.length - 1}
                        className="absolute right-4 top-1/2 -translate-y-1/2 p-2 bg-black/50 text-white rounded-full transition-opacity hover:bg-gray-700 disabled:opacity-30 disabled:cursor-not-allowed btn-press-feedback"
                        aria-label="Next image"
                    >
                        <ChevronRightIcon className="w-8 h-8" />
                    </button>
                </>
            )}


            {/* Mobile-only selection button */}
            <div className="md:hidden absolute bottom-6 left-1/2 -translate-x-1/2">
                <button
                    onClick={onToggleSelect}
                    className={`flex items-center gap-2 px-4 py-2 rounded-full font-semibold transition-all duration-200 text-sm btn-press-feedback
                        ${isSelected
                            ? 'bg-teal-600 text-white'
                            : 'bg-gray-200 text-gray-800 hover:bg-white'
                        }`
                    }
                >
                    {isSelected ? <CheckCircleIcon className="w-5 h-5" /> : <PlusCircleIcon className="w-5 h-5" />}
                    {isSelected ? 'Selected' : 'Add to Selection'}
                </button>
            </div>
        </motion.div>
    );
};

export default FullScreenImageViewer;

================
File: components/HistoryViewer.tsx
================
import React from 'react';
import { ImageNode } from '../types';
import { XIcon } from './Icons';
import { motion } from 'framer-motion';

interface HistoryViewerProps {
    path: ImageNode[];
    onClose: () => void;
}

const HistoryViewer: React.FC<HistoryViewerProps> = ({ path, onClose }) => {
    if (path.length === 0) return null;

    return (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 backdrop-blur-sm" onClick={onClose}>
            <motion.div 
                className="bg-gray-800 rounded-lg shadow-xl w-full max-w-lg mx-4 flex flex-col max-h-[80vh]" 
                onClick={e => e.stopPropagation()}
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.2 }}
                role="dialog"
                aria-modal="true"
            >
                <div className="flex justify-between items-center p-4 border-b border-gray-700">
                    <h2 className="text-xl font-bold text-gray-100">Image Ancestry</h2>
                    <button onClick={onClose} className="text-gray-400 hover:text-white text-2xl leading-none">&times;</button>
                </div>
                <div className="p-6 overflow-y-auto space-y-4">
                    {path.map((node, index) => (
                        <React.Fragment key={node.id}>
                            <div className="flex items-start gap-4 p-3 bg-gray-700/50 rounded-lg">
                                <img 
                                    src={node.imageUrl} 
                                    alt={node.prompt} 
                                    className="w-20 h-20 object-cover rounded-md flex-shrink-0" 
                                    loading="lazy" 
                                    decoding="async"
                                />
                                <div className="text-sm">
                                    <span className="font-bold text-teal-400">Generation {node.generation}</span>
                                    <p className="text-gray-300 mt-1 line-clamp-3">{node.prompt}</p>
                                </div>
                            </div>
                            {index < path.length - 1 && (
                                <div className="flex justify-center">
                                    <div className="h-6 w-px bg-gray-600" />
                                </div>
                            )}
                        </React.Fragment>
                    ))}
                </div>
            </motion.div>
        </div>
    );
};

export default HistoryViewer;

================
File: components/Icons.tsx
================
import React from 'react';

type IconProps = React.SVGProps<SVGSVGElement>;

export const UploadIcon: React.FC<IconProps> = (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5m-13.5-9L12 3m0 0 4.5 4.5M12 3v13.5" />
    </svg>
);

export const SparklesIcon: React.FC<IconProps> = (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456Z" />
    </svg>
);

export const XIcon: React.FC<IconProps> = (props) => (
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M6 18 18 6M6 6l12 12" />
  </svg>
);

export const CheckIcon: React.FC<IconProps> = (props) => (
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
    <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" />
  </svg>
);

export const CursorArrowRaysIcon: React.FC<IconProps> = (props) => (
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M15.042 21.672 13.684 16.6m0 0-2.51 2.225.569-9.47 5.227 7.917-3.286-.672ZM12 2.25V4.5m5.834.166-1.591 1.591M20.25 10.5H18M5.834 7.166 4.242 5.575M18 18.75l-1.591-1.591M5.834 16.834 4.242 18.425M12 21.75V19.5" />
  </svg>
);

export const TrashIcon: React.FC<IconProps> = (props) => (
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
    <path strokeLinecap="round" strokeLinejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 4.811 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.134-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.067-2.09.92-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
  </svg>
);

export const CogIcon: React.FC<IconProps> = (props) => (
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12a7.5 7.5 0 0 0 15 0m-15 0a7.5 7.5 0 1 1 15 0m-15 0H3m18 0h-1.5m-15 0a7.5 7.5 0 1 1 15 0m-15 0h.008v.008H4.5v-.008Zm15 0h.008v.008h-.008v-.008Zm-7.5 0h.008v.008h-.008v-.008Zm-3.75 0h.008v.008h-.008v-.008Zm7.5 0h.008v.008h-.008v-.008Z" />
  </svg>
);

export const ChevronUpIcon: React.FC<IconProps> = (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
        <path strokeLinecap="round" strokeLinejoin="round" d="m4.5 15.75 7.5-7.5 7.5 7.5" />
    </svg>
);

export const ChevronDownIcon: React.FC<IconProps> = (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
        <path strokeLinecap="round" strokeLinejoin="round" d="m19.5 8.25-7.5 7.5-7.5-7.5" />
    </svg>
);

export const ChevronLeftIcon: React.FC<IconProps> = (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5 8.25 12l7.5-7.5" />
    </svg>
);

export const ChevronRightIcon: React.FC<IconProps> = (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
        <path strokeLinecap="round" strokeLinejoin="round" d="m8.25 4.5 7.5 7.5-7.5 7.5" />
    </svg>
);

export const PlusCircleIcon: React.FC<IconProps> = (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
    </svg>
);

export const CheckCircleIcon: React.FC<IconProps> = (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
    </svg>
);

export const DocumentPlusIcon: React.FC<IconProps> = (props) => (
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M12 10.5v6m3-3H9m4.06-7.19-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" />
  </svg>
);

export const PaperClipIcon: React.FC<IconProps> = (props) => (
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M9.562 14.438 15 9a3 3 0 1 0-4.243-4.243L6.343 9.17a4.5 4.5 0 1 0 6.364 6.364l5.303-5.303" />
  </svg>
);

export const HistoryIcon: React.FC<IconProps> = (props) => (
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M12 6.042A8.967 8.967 0 0 0 6 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 0 1 6 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 0 1 6-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0 0 18 18a8.967 8.967 0 0 0-6 2.292m0-14.25v14.25" />
  </svg>
);

export const InfoIcon: React.FC<IconProps> = (props) => (
  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
    <path strokeLinecap="round" strokeLinejoin="round" d="m11.25 11.25.041-.02a.75.75 0 0 1 1.063.852l-.708 2.836a.75.75 0 0 0 1.063.853l.041-.021M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-3.75h.008v.008H12V8.25Z" />
  </svg>
);

export const ArrowUturnLeftIcon: React.FC<IconProps> = (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M9 15 3 9m0 0 6-6M3 9h12a6 6 0 0 1 0 12h-3" />
    </svg>
);

export const ArrowsPointingOutIcon: React.FC<IconProps> = (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" {...props}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M20.25 20.25v-4.5m0 4.5h-4.5m4.5 0L15 15m-6 0L3.75 20.25m16.5-16.5L15 9m-6 6 6 6" />
    </svg>
);

================
File: components/ImageTree.tsx
================
import React, { useEffect, useMemo, useRef, useState } from 'react';
import { ImageNode, GhostNode } from '../types';
import { CursorArrowRaysIcon, InfoIcon } from './Icons';

type DisplayNode = (ImageNode | GhostNode) & { isGhost?: boolean };

interface ImageTreeProps {
  nodes: ImageNode[];
  ghostNodes: GhostNode[];
  selectedNodeIds: Set<string>;
  onNodeClick: (node: ImageNode, event: React.MouseEvent | MouseEvent) => void;
  onNodeView: (node: ImageNode) => void;
  isSelectMode: boolean;
  setIsSelectMode: (isSelectMode: boolean) => void;
  onDeleteNode: (node: ImageNode) => void;
}

// New implementation: canvas/SVG hybrid with CSS transform pan/zoom
const ImageTree: React.FC<ImageTreeProps> = ({
  nodes,
  ghostNodes,
  selectedNodeIds,
  onNodeClick,
  onNodeView,
  isSelectMode,
  setIsSelectMode,
  onDeleteNode,
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);
  const svgRef = useRef<SVGSVGElement>(null);

  // Persistent in-memory positions for nodes by id
  const positionsRef = useRef<Map<string, { x: number; y: number }>>(new Map());
  const appearedOnceRef = useRef<Set<string>>(new Set());
  const [tick, setTick] = useState(0); // minimal re-render signal for edges/labels during drag

  const [transform, setTransform] = useState({ x: 0, y: 0, k: 1 });
  const isPanningRef = useRef(false);
  const panStartRef = useRef<{ x: number; y: number } | null>(null);
  const transformStartRef = useRef<{ x: number; y: number } | null>(null);
  const draggingNodeRef = useRef<string | null>(null);
  const pointersRef = useRef<Map<number, { x: number; y: number }>>(new Map());
  const pinchStartRef = useRef<{
    k: number;
    x: number;
    y: number;
    cx: number;
    cy: number;
    d: number;
  } | null>(null);

  const STORAGE_KEY = 'imageTreePositions';
  const GRID = 24; // px grid for subtle snapping

  const clamp = (v: number, min: number, max: number) => Math.max(min, Math.min(max, v));

  const savePositionsToStorage = () => {
    const map = positionsRef.current;
    const json = JSON.stringify(Object.fromEntries(Array.from(map.entries())));
    try { localStorage.setItem(STORAGE_KEY, json); } catch {}
  };
  const loadPositionsFromStorage = (): Map<string, { x: number; y: number }> => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return new Map();
      const obj = JSON.parse(raw) as Record<string, { x: number; y: number }>;
      return new Map(Object.entries(obj));
    } catch {
      return new Map();
    }
  };

  const displayNodes: DisplayNode[] = useMemo(
    () => [
      ...nodes,
      ...ghostNodes.map((g) => ({ ...g, isGhost: true })),
    ],
    [nodes, ghostNodes]
  );

  // Utility for consistent node size across generations
  const getNodeSize = (generation: number) => {
    const base = 120; // px
    return Math.max(70, Math.round(base * Math.pow(0.9, generation)));
  };

  const sizeById = useMemo(() => {
    const map = new Map<string, number>();
    for (const n of displayNodes) {
      const generation = (n as ImageNode).generation ?? 0;
      map.set(n.id, getNodeSize(generation));
    }
    return map;
  }, [displayNodes]);

  // Ensure new nodes have initial positions (near their first parent or near center)
  useEffect(() => {
    const center = () => {
      const rect = containerRef.current?.getBoundingClientRect();
      return {
        x: (rect?.width || 800) / 2,
        y: (rect?.height || 600) / 2,
      };
    };

    // seed with any saved positions
    const saved = loadPositionsFromStorage();
    const map = positionsRef.current;
    const currentCenter = center();
    const byId = new Map<string, DisplayNode>();
    displayNodes.forEach((n) => byId.set(n.id, n));
    let added = false;
    const minSeparation = 40;
    const goldenAngle = Math.PI * (3 - Math.sqrt(5));

    const collides = (cx: number, cy: number, nodeSize: number) => {
      for (const [otherId, otherPos] of map.entries()) {
        const otherNode = byId.get(otherId);
        if (!otherNode) continue;
        const otherSize = sizeById.get(otherId) ?? getNodeSize(((otherNode as ImageNode).generation) ?? 0);
        const dx = otherPos.x - cx;
        const dy = otherPos.y - cy;
        const distance = Math.hypot(dx, dy);
        const safeRadius = (nodeSize + otherSize) / 2 + minSeparation;
        if (distance < safeRadius) return true;
      }
      return false;
    };

    const findSlotNear = (
      anchor: { x: number; y: number },
      node: DisplayNode,
      initialRadius: number
    ) => {
      const nodeSize = sizeById.get(node.id) ?? getNodeSize(((node as ImageNode).generation) ?? 0);
      const attemptsPerRing = 20;
      const randomOffset = Math.random() * Math.PI * 2;
      let radius = initialRadius;

      for (let ring = 0; ring < 6; ring++) {
        for (let stepIndex = 0; stepIndex < attemptsPerRing; stepIndex++) {
          const angle = randomOffset + stepIndex * goldenAngle;
          const rawX = anchor.x + Math.cos(angle) * radius;
          const rawY = anchor.y + Math.sin(angle) * radius;
          const snappedX = Math.round(rawX / GRID) * GRID;
          const snappedY = Math.round(rawY / GRID) * GRID;
          if (!collides(snappedX, snappedY, nodeSize)) {
            return { x: snappedX, y: snappedY };
          }
        }
        radius += nodeSize + minSeparation;
      }

      // fallback: spiral search expanding outward until a gap is found
      let fallbackRadius = radius;
      let angle = randomOffset;
      for (let tries = 0; tries < 64; tries++) {
        const rawX = anchor.x + Math.cos(angle) * fallbackRadius;
        const rawY = anchor.y + Math.sin(angle) * fallbackRadius;
        const snappedX = Math.round(rawX / GRID) * GRID;
        const snappedY = Math.round(rawY / GRID) * GRID;
        if (!collides(snappedX, snappedY, sizeById.get(node.id) ?? getNodeSize(((node as ImageNode).generation) ?? 0))) {
          return { x: snappedX, y: snappedY };
        }
        fallbackRadius += (sizeById.get(node.id) ?? getNodeSize(((node as ImageNode).generation) ?? 0)) * 0.35;
        angle += goldenAngle;
      }

      return { x: anchor.x + Math.cos(angle) * fallbackRadius, y: anchor.y + Math.sin(angle) * fallbackRadius };
    };

    for (const n of displayNodes) {
      if (map.has(n.id)) continue;
      if (saved.has(n.id)) {
        map.set(n.id, saved.get(n.id)!);
        added = true;
        continue;
      }
      const nodeSize = sizeById.get(n.id) ?? getNodeSize(((n as ImageNode).generation) ?? 0);
      let pos = currentCenter;
      const pId = n.parentIds?.[0];
      if (pId && map.has(pId)) {
        const p = map.get(pId)!;
        const parentNode = byId.get(pId);
        const parentSize = parentNode ? (sizeById.get(pId) ?? getNodeSize(((parentNode as ImageNode).generation) ?? 0)) : nodeSize;
        const startRadius = parentSize / 2 + nodeSize / 2 + minSeparation + 80;
        pos = findSlotNear(p, n, startRadius);
      } else {
        const startRadius = Math.max(280, nodeSize + minSeparation + 120);
        pos = findSlotNear(currentCenter, n, startRadius);
      }
      map.set(n.id, { x: pos.x, y: pos.y });
      appearedOnceRef.current.add(n.id);
      setTimeout(() => {
        appearedOnceRef.current.delete(n.id);
      }, 500);
      added = true;
    }
    if (added) setTick((v) => v + 1);
  }, [displayNodes, sizeById]);

  // Center the 4000x4000 content on first mount
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    if (transform.x !== 0 || transform.y !== 0) return;
    const rect = container.getBoundingClientRect();
    const initX = rect.width / 2 - 2000;
    const initY = rect.height / 2 - 2000;
    setTransform((t) => ({ ...t, x: initX, y: initY }));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Pan + pinch handlers
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const updatePointer = (e: PointerEvent) => {
      pointersRef.current.set(e.pointerId, { x: e.clientX, y: e.clientY });
    };

    const onPointerDown = (e: PointerEvent) => {
      // Ignore if starting on a node (node handlers will manage drag)
      const target = e.target as HTMLElement;
      if (!target.closest('.graph-node')) {
        updatePointer(e);
        container.setPointerCapture(e.pointerId);
        if (pointersRef.current.size >= 2) {
          // start pinch
          const pts = Array.from(pointersRef.current.values());
          const rect = container.getBoundingClientRect();
          const cx = (pts[0].x + pts[1].x) / 2 - rect.left;
          const cy = (pts[0].y + pts[1].y) / 2 - rect.top;
          const dx = pts[0].x - pts[1].x;
          const dy = pts[0].y - pts[1].y;
          const d = Math.hypot(dx, dy);
          pinchStartRef.current = { k: transform.k, x: transform.x, y: transform.y, cx, cy, d };
        } else {
          // start pan
          isPanningRef.current = true;
          panStartRef.current = { x: e.clientX, y: e.clientY };
          transformStartRef.current = { x: transform.x, y: transform.y };
        }
      }
    };

    const onPointerMove = (e: PointerEvent) => {
      if ((e.buttons & 1) === 0) return; // only when primary down
      updatePointer(e);
      if (pinchStartRef.current && pointersRef.current.size >= 2) {
        const pts = Array.from(pointersRef.current.values());
        const rect = container.getBoundingClientRect();
        const cx = (pts[0].x + pts[1].x) / 2 - rect.left;
        const cy = (pts[0].y + pts[1].y) / 2 - rect.top;
        const dx = pts[0].x - pts[1].x;
        const dy = pts[0].y - pts[1].y;
        const d = Math.hypot(dx, dy);
        const start = pinchStartRef.current;
        const kNew = clamp(start.k * (d / start.d), 0.1, 4);
        const ratio = kNew / start.k;
        const xNew = cx - (start.cx - start.x) * ratio;
        const yNew = cy - (start.cy - start.y) * ratio;
        setTransform({ x: xNew, y: yNew, k: kNew });
        return;
      }
      if (!isPanningRef.current) return;
      const start = panStartRef.current;
      const base = transformStartRef.current;
      if (!start || !base) return;
      const dx = e.clientX - start.x;
      const dy = e.clientY - start.y;
      setTransform((t) => ({ ...t, x: base.x + dx, y: base.y + dy }));
    };

    const onPointerUp = (e: PointerEvent) => {
      pointersRef.current.delete(e.pointerId);
      if (pointersRef.current.size < 2) pinchStartRef.current = null;
      isPanningRef.current = false;
      panStartRef.current = null;
      transformStartRef.current = null;
      try { container.releasePointerCapture(e.pointerId); } catch {}
    };

    const onWheel = (e: WheelEvent) => {
      if (!contentRef.current) return;
      e.preventDefault();
      const scaleFactor = 1.08;
      const direction = e.deltaY < 0 ? 1 : -1;
      const kNew = Math.min(4, Math.max(0.1, transform.k * (direction > 0 ? scaleFactor : 1 / scaleFactor)));

      // Zoom towards pointer location
      const rect = container.getBoundingClientRect();
      const px = e.clientX - rect.left;
      const py = e.clientY - rect.top;
      const kRatio = kNew / transform.k;
      const xNew = px - (px - transform.x) * kRatio;
      const yNew = py - (py - transform.y) * kRatio;
      setTransform({ x: xNew, y: yNew, k: kNew });
    };

    container.addEventListener('pointerdown', onPointerDown);
    container.addEventListener('pointermove', onPointerMove);
    container.addEventListener('pointerup', onPointerUp);
    container.addEventListener('pointercancel', onPointerUp);
    container.addEventListener('wheel', onWheel, { passive: false });
    return () => {
      container.removeEventListener('pointerdown', onPointerDown);
      container.removeEventListener('pointermove', onPointerMove);
      container.removeEventListener('pointerup', onPointerUp);
      container.removeEventListener('pointercancel', onPointerUp);
      container.removeEventListener('wheel', onWheel);
    };
  }, [transform.k, transform.x, transform.y]);

  // Node drag handlers via pointer events on each node
  const attachNodeDrag = (id: string, el: HTMLDivElement | null) => {
    if (!el) return;
    if ((el as any).__dragBound) return;
    (el as any).__dragBound = true;
    const onPointerDown = (e: PointerEvent) => {
      draggingNodeRef.current = id;
      let pos = positionsRef.current.get(id);
      if (!pos) {
        // Seed a safe default at center if missing
        const rect = containerRef.current?.getBoundingClientRect();
        pos = { x: (rect?.width || 800) / 2, y: (rect?.height || 600) / 2 };
        positionsRef.current.set(id, pos);
      }
      el.setPointerCapture(e.pointerId);
      const rect = containerRef.current?.getBoundingClientRect();
      const sceneX = ((e.clientX - (rect?.left || 0)) - transform.x) / transform.k;
      const sceneY = ((e.clientY - (rect?.top || 0)) - transform.y) / transform.k;
      el.dataset.sdx = String(sceneX - pos.x);
      el.dataset.sdy = String(sceneY - pos.y);
      e.stopPropagation(); // avoid panning start
    };
    const onPointerMove = (e: PointerEvent) => {
      if (draggingNodeRef.current !== id) return;
      const dx = Number(el.dataset.sdx || 0);
      const dy = Number(el.dataset.sdy || 0);
      const map = positionsRef.current;
      const rect = containerRef.current?.getBoundingClientRect();
      const sceneX = ((e.clientX - (rect?.left || 0)) - transform.x) / transform.k;
      const sceneY = ((e.clientY - (rect?.top || 0)) - transform.y) / transform.k;
      let nx = (sceneX - dx);
      let ny = (sceneY - dy);
      // snap to subtle grid
      nx = Math.round(nx / GRID) * GRID;
      ny = Math.round(ny / GRID) * GRID;
      map.set(id, { x: nx, y: ny });
      setTick((v) => v + 1);
    };
    const onPointerUp = (e: PointerEvent) => {
      draggingNodeRef.current = null;
      try { el.releasePointerCapture(e.pointerId); } catch {}
      savePositionsToStorage();
    };
    el.addEventListener('pointerdown', onPointerDown);
    el.addEventListener('pointermove', onPointerMove);
    el.addEventListener('pointerup', onPointerUp);
    el.addEventListener('pointercancel', onPointerUp);
  };

  // Compute edges based on parent relationships
  const edges = useMemo(() => {
    const map = positionsRef.current;
    const idSet = new Set(displayNodes.map((n) => n.id));
    const result: { id: string; source: string; target: string }[] = [];
    for (const n of displayNodes) {
      for (const p of n.parentIds || []) {
        if (idSet.has(p)) result.push({ id: `${p}->${n.id}`, source: p, target: n.id });
      }
    }
    return result;
  }, [displayNodes]);

  // Utility: zoom to fit ids (or all)
  const zoomToFit = (ids?: string[]) => {
    const container = containerRef.current;
    if (!container) return;
    const rect = container.getBoundingClientRect();
    const PAD = 80;
    const map = positionsRef.current;
    const list = (ids && ids.length ? ids : Array.from(map.keys()))
      .map((id) => ({ id, pos: map.get(id) }))
      .filter((e): e is { id: string; pos: { x: number; y: number } } => !!e.pos);
    if (list.length === 0) return;
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (const { id, pos } of list) {
      const d = displayNodes.find((n) => n.id === id);
      const size = getNodeSize(((d as any)?.generation) ?? 0);
      const x1 = pos.x - size / 2, y1 = pos.y - size / 2;
      const x2 = pos.x + size / 2, y2 = pos.y + size / 2;
      minX = Math.min(minX, x1); minY = Math.min(minY, y1);
      maxX = Math.max(maxX, x2); maxY = Math.max(maxY, y2);
    }
    const w = Math.max(1, maxX - minX);
    const h = Math.max(1, maxY - minY);
    const k = clamp(Math.min((rect.width - PAD) / w, (rect.height - PAD) / h), 0.1, 4);
    const x = rect.width / 2 - (minX + w / 2) * k;
    const y = rect.height / 2 - (minY + h / 2) * k;
    setTransform({ x, y, k });
  };

  const resetView = () => {
    const container = containerRef.current;
    if (!container) return;
    const rect = container.getBoundingClientRect();
    const initX = rect.width / 2 - 2000;
    const initY = rect.height / 2 - 2000;
    setTransform((t) => ({ ...t, x: initX, y: initY, k: 1 }));
  };

  // Apply transform style to content
  const contentStyle: React.CSSProperties = {
    transform: `translate(${transform.x}px, ${transform.y}px) scale(${transform.k})`,
    transformOrigin: '0 0',
    width: 4000,
    height: 4000,
    position: 'absolute',
    inset: 0,
  };

  // Ensure a position exists for an id and return it
  const ensurePos = (id: string): { x: number; y: number } => {
    let pos = positionsRef.current.get(id);
    if (!pos) {
      // seed to scene center and trigger a refresh
      pos = { x: 2000, y: 2000 };
      positionsRef.current.set(id, pos);
      setTick((v) => v + 1);
    }
    return pos;
  };

  return (
    <div
      ref={containerRef}
      className="w-full h-full bg-black/20 relative overflow-hidden"
      style={{ touchAction: 'none', cursor: draggingNodeRef.current ? 'grabbing' : (isPanningRef.current ? 'grabbing' : 'grab') }}
    >
      {/* Help tooltip button */}
      <InfoButton />
      <div ref={contentRef} className="will-change-transform" style={contentStyle}>
        <svg ref={svgRef} width="4000" height="4000" style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
          <g>
            {edges.map((e) => {
              const s = ensurePos(e.source);
              const t = ensurePos(e.target);
              return (
                <line
                  key={e.id}
                  x1={s.x}
                  y1={s.y}
                  x2={t.x}
                  y2={t.y}
                  stroke="#4a5568"
                  strokeWidth={2}
                  strokeOpacity={0.9}
                />
              );
            })}
          </g>
        </svg>

        <div className="absolute inset-0" style={{ position: 'absolute' }}>
          {displayNodes.map((n) => {
            const pos = ensurePos(n.id);
            const size = getNodeSize((n as ImageNode).generation || 0);
            const isSelected = selectedNodeIds.has(n.id);
            const isGhost = (n as any).isGhost;
            const shouldAnimate = !isGhost && appearedOnceRef.current.has(n.id);
            return (
              <div
                key={n.id}
                ref={(el) => attachNodeDrag(n.id, el)}
                className="graph-node"
                style={{
                  position: 'absolute',
                  left: pos.x - size / 2,
                  top: pos.y - size / 2,
                  width: size,
                  height: size,
                  borderRadius: '22% / 22%',
                  border: `2px solid ${isSelected ? '#63b3ed' : '#4a5568'}`,
                  boxShadow: isSelected
                    ? '0 0 14px rgba(99,179,237,0.8)'
                    : isGhost
                    ? '0 0 0 0 rgba(255,255,255,0.0)'
                    : '0 6px 12px rgba(0,0,0,0.35)',
                  background: 'rgba(255,255,255,0.05)',
                  overflow: 'hidden',
                  userSelect: 'none',
                  touchAction: 'none',
                  animation: shouldAnimate ? 'node-appear 0.35s ease-out both' : undefined,
                }}
                onClick={(e) => {
                  if (isGhost) return; // ignore selection for ghost placeholders
                  onNodeClick(n as ImageNode, e.nativeEvent);
                  const isMulti = (e.metaKey || e.ctrlKey || isSelectMode);
                  if (!isMulti) onNodeView(n as ImageNode);
                }}
              >
                {isGhost ? (
                  <div className="w-full h-full animate-pulse" style={{ background: 'linear-gradient(135deg, rgba(255,255,255,0.06), rgba(255,255,255,0.02))' }} />
                ) : (
                  <img
                    src={(n as ImageNode).imageUrl}
                    alt=""
                    draggable={false}
                    loading="lazy"
                    style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: 'inherit' }}
                  />
                )}
                {/* badge */}
                <div
                  style={{
                    position: 'absolute',
                    left: 4,
                    bottom: 4,
                    background: 'rgba(0,0,0,0.55)',
                    color: '#cbd5e1',
                    fontSize: 10,
                    padding: '2px 6px',
                    borderRadius: 8,
                    lineHeight: 1,
                    pointerEvents: 'none'
                  }}
                  title={`Generation ${((n as any).generation ?? 0)}`}
                >
                  Gen {(n as any).generation ?? 0}
                </div>
                {!isGhost && (
                  <button
                    className="delete-button"
                    onClick={(e) => {
                      e.stopPropagation();
                      onDeleteNode(n as ImageNode);
                    }}
                    title="Delete"
                    style={{
                      position: 'absolute',
                      top: -6,
                      right: -6,
                      width: 22,
                      height: 22,
                      borderRadius: '50%',
                      background: '#ef4444',
                      color: '#fff',
                      border: 'none',
                      display: isSelected ? 'flex' : 'none',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: 14,
                      lineHeight: 1,
                      boxShadow: '0 2px 6px rgba(0,0,0,0.35)'
                    }}
                  >
                    ×
                  </button>
                )}
              </div>
            );
          })}
        </div>
      </div>

      <div className="absolute bottom-2 right-2 z-10">
        <button
          type="button"
          onClick={() => setIsSelectMode(!isSelectMode)}
          className={`flex items-center justify-center px-3 py-1.5 border rounded-md text-xs font-medium transition-colors shadow-lg btn-press-feedback ${
            isSelectMode
              ? 'bg-blue-600 border-blue-500 text-white'
              : 'bg-gray-800/60 border-gray-600 hover:bg-gray-700 text-gray-300 backdrop-blur-sm'
          }`}
          title="Toggle Multi-Select Mode (or use Cmd/Ctrl+Click)"
        >
          <CursorArrowRaysIcon className="w-4 h-4 mr-1.5" />
          <span>Multi-Select</span>
        </button>
      </div>
      <div className="absolute top-2 right-2 z-10 flex gap-2">
        <button
          className="px-2 py-1 text-xs rounded bg-gray-800/70 border border-gray-600 text-gray-200 hover:bg-gray-700"
          onClick={() => zoomToFit(Array.from(selectedNodeIds))}
          title="Fit Selected"
          disabled={selectedNodeIds.size === 0}
        >Fit Sel</button>
        <button
          className="px-2 py-1 text-xs rounded bg-gray-800/70 border border-gray-600 text-gray-200 hover:bg-gray-700"
          onClick={() => zoomToFit()}
          title="Fit All"
        >Fit All</button>
        <button
          className="px-2 py-1 text-xs rounded bg-gray-800/70 border border-gray-600 text-gray-200 hover:bg-gray-700"
          onClick={resetView}
          title="Reset View"
        >Reset</button>
      </div>
    </div>
  );
};

export default ImageTree;

// Inline helper component: info button with hover/focus tooltip
const InfoButton: React.FC = () => {
  const [open, setOpen] = React.useState(false);
  const text = 'Drag anywhere to pan. Scroll/pinch to zoom. Click to view. Cmd/Ctrl+Click to multi-select. Drag a node to reposition.';
  return (
    <div
      className="absolute top-2 left-2 z-10"
      onMouseEnter={() => setOpen(true)}
      onMouseLeave={() => setOpen(false)}
    >
      <button
        type="button"
        aria-label="Canvas help"
        onFocus={() => setOpen(true)}
        onBlur={() => setOpen(false)}
        onClick={() => setOpen((v) => !v)}
        style={{
          width: 26,
          height: 26,
          borderRadius: 999,
          background: 'rgba(17,24,39,0.7)',
          border: '1px solid #4b5563',
          color: '#e5e7eb',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          boxShadow: '0 2px 8px rgba(0,0,0,0.35)'
        }}
        title="Help"
      >
        <InfoIcon className="w-4 h-4" />
      </button>
      {open && (
        <div
          role="tooltip"
          style={{
            position: 'absolute',
            left: 34,
            top: -2,
            maxWidth: 360,
            background: 'rgba(0,0,0,0.74)',
            color: '#cbd5e1',
            fontSize: 12,
            padding: '8px 10px',
            borderRadius: 8,
            border: '1px solid #374151',
            boxShadow: '0 8px 20px rgba(0,0,0,0.45)'
          }}
        >
          {text}
        </div>
      )}
    </div>
  );
};

================
File: components/ImageViewer.tsx
================
import React, { useMemo, useRef } from 'react';
import { ImageNode } from '../types';
import { XIcon, PlusCircleIcon, CheckCircleIcon, HistoryIcon, TrashIcon, ChevronLeftIcon, ChevronRightIcon, ArrowsPointingOutIcon } from './Icons';

interface ImageViewerProps {
    node?: ImageNode;
    isModal: boolean;
    onClose: () => void;
    isSelected: boolean;
    onToggleSelect: () => void;
    onShowHistory: (node: ImageNode) => void;
    onDelete: (node: ImageNode) => void;
    onOpenFullScreen: (node: ImageNode) => void;
    carouselNodes: ImageNode[];
    onNavigate: (node: ImageNode) => void;
    showCloseButton?: boolean;
}

const ImageViewer: React.FC<ImageViewerProps> = ({
    node,
    isModal,
    onClose,
    isSelected,
    onToggleSelect,
    onShowHistory,
    onDelete,
    onOpenFullScreen,
    carouselNodes,
    onNavigate,
    showCloseButton
}) => {
    // Refs for swipe gesture
    const touchStartRef = useRef<number | null>(null);
    const touchEndRef = useRef<number | null>(null);
    const minSwipeDistance = 50;

    const currentIndex = useMemo(() => {
        if (!node) return -1;
        return carouselNodes.findIndex(n => n.id === node.id);
    }, [carouselNodes, node]);

    const handlePrev = (e?: React.MouseEvent) => {
        e?.stopPropagation();
        if (currentIndex > 0) {
            onNavigate(carouselNodes[currentIndex - 1]);
        }
    };

    const handleNext = (e?: React.MouseEvent) => {
        e?.stopPropagation();
        if (currentIndex < carouselNodes.length - 1) {
            onNavigate(carouselNodes[currentIndex + 1]);
        }
    };
    
    const onTouchStart = (e: React.TouchEvent) => {
        touchEndRef.current = null;
        touchStartRef.current = e.targetTouches[0].clientX;
    };

    const onTouchMove = (e: React.TouchEvent) => {
        touchEndRef.current = e.targetTouches[0].clientX;
    };

    const onTouchEnd = () => {
        if (!touchStartRef.current || !touchEndRef.current) return;
        const distance = touchStartRef.current - touchEndRef.current;
        const isLeftSwipe = distance > minSwipeDistance;
        const isRightSwipe = distance < -minSwipeDistance;
        
        if (isLeftSwipe) handleNext();
        else if (isRightSwipe) handlePrev();
        
        touchStartRef.current = null;
        touchEndRef.current = null;
    };
    
    if (!node) {
        if (isModal) return null; // Don't render an empty modal
        return (
            <div className="w-full h-full flex items-center justify-center bg-black/20">
                <p className="text-gray-500">Select an image node to view it.</p>
            </div>
        );
    }
    
    const viewerContent = (
        <div 
            className="relative w-full h-full flex flex-col items-center justify-center p-4 group" 
            onClick={e => e.stopPropagation()}
            onTouchStart={onTouchStart}
            onTouchMove={onTouchMove}
            onTouchEnd={onTouchEnd}
        >
            <img
                src={node.imageUrl}
                alt={node.prompt}
                className="max-w-full max-h-full object-contain rounded-lg shadow-2xl"
                fetchPriority="high"
            />
            
            <div className="absolute top-4 right-4 flex items-center gap-2">
                 <button
                    onClick={(e) => { e.stopPropagation(); onOpenFullScreen(node); }}
                    className="p-2 bg-black/50 hover:bg-teal-600 text-white rounded-full transition-colors btn-press-feedback"
                    aria-label="View full screen"
                >
                    <ArrowsPointingOutIcon className="w-5 h-5"/>
                </button>
                 <button
                    onClick={(e) => { e.stopPropagation(); onDelete(node); }}
                    className="p-2 bg-black/50 hover:bg-red-600 text-white rounded-full transition-colors btn-press-feedback"
                    aria-label="Delete node"
                >
                    <TrashIcon className="w-5 h-5"/>
                </button>
                <button
                    onClick={(e) => { e.stopPropagation(); onShowHistory(node); }}
                    className="p-2 bg-black/50 hover:bg-blue-600 text-white rounded-full transition-colors btn-press-feedback"
                    aria-label="Show image history"
                >
                    <HistoryIcon className="w-5 h-5"/>
                </button>
            </div>
            
            {(isModal || showCloseButton) && (
                <div className="absolute top-4 left-4">
                    <button
                        onClick={(e) => { e.stopPropagation(); onClose(); }}
                        className="p-2 bg-black/50 hover:bg-gray-700 text-white rounded-full transition-colors btn-press-feedback"
                        aria-label="Close viewer"
                    >
                        <XIcon className="w-5 h-5"/>
                    </button>
                </div>
            )}
            
            <div className="absolute bottom-4 left-4 right-4 bg-black/60 backdrop-blur-sm p-2 rounded-md">
                <p className="text-xs text-gray-400 font-mono line-clamp-2">{node.prompt}</p>
            </div>

            {/* Carousel Navigation */}
            {carouselNodes.length > 1 && (
                <>
                    <button 
                        onClick={handlePrev} 
                        disabled={currentIndex <= 0}
                        className="absolute left-2 md:left-4 top-1/2 -translate-y-1/2 p-2 bg-black/50 text-white rounded-full transition-opacity hover:bg-gray-700 disabled:opacity-30 disabled:cursor-not-allowed btn-press-feedback"
                        aria-label="Previous image"
                    >
                        <ChevronLeftIcon className="w-6 h-6" />
                    </button>
                     <button 
                        onClick={handleNext} 
                        disabled={currentIndex >= carouselNodes.length - 1}
                        className="absolute right-2 md:right-4 top-1/2 -translate-y-1/2 p-2 bg-black/50 text-white rounded-full transition-opacity hover:bg-gray-700 disabled:opacity-30 disabled:cursor-not-allowed btn-press-feedback"
                        aria-label="Next image"
                    >
                        <ChevronRightIcon className="w-6 h-6" />
                    </button>
                </>
            )}

            {/* Mobile-only selection button */}
            {(isModal || showCloseButton) && (
                <div className="absolute bottom-16 left-1/2 -translate-x-1/2">
                    <button
                        onClick={(e) => { e.stopPropagation(); onToggleSelect(); }}
                        className={`flex items-center gap-2 px-4 py-2 rounded-full font-semibold transition-all duration-200 text-sm shadow-lg btn-press-feedback
                            ${isSelected
                                ? 'bg-teal-600 text-white'
                                : 'bg-gray-200 text-gray-800 hover:bg-white'
                            }`
                        }
                    >
                        {isSelected ? <CheckCircleIcon className="w-5 h-5" /> : <PlusCircleIcon className="w-5 h-5" />}
                        {isSelected ? 'Selected' : 'Add to Selection'}
                    </button>
                </div>
            )}
        </div>
    );
    
    if (isModal) {
         return (
            <div 
                className="fixed inset-0 bg-black/90 flex items-center justify-center z-40 backdrop-blur-md animate-modal-enter"
                onClick={onClose}
            >
                {viewerContent}
            </div>
        );
    }

    // Desktop Panel View
    return (
        <div className="w-full h-full bg-black/20">
           {viewerContent}
        </div>
    );
};

export default ImageViewer;

================
File: components/Loader.tsx
================
import React from 'react';

interface LoaderProps {
    message: string;
}

const Loader: React.FC<LoaderProps> = ({ message }) => {
    return (
        <div className="fixed inset-0 bg-black/80 flex flex-col items-center justify-center z-50 backdrop-blur-sm">
            <div className="w-16 h-16 border-4 border-t-teal-400 border-gray-600 rounded-full animate-spin"></div>
            <div className="w-64 mt-6 text-center">
                <p className="text-lg text-gray-300">{message}</p>
                 <p className="text-xs text-gray-400 mt-2">
                    (Image generation happens in-place in the node diagram)
                </p>
            </div>
        </div>
    );
};

export default Loader;

================
File: components/Panel.tsx
================
import React from 'react';
import { PanelContent, DropTarget, DropPosition } from '../types';
import { ChevronDownIcon } from './Icons';
import PanelDropZone from './PanelDropZone';

interface PanelProps {
  id: string;
  content: PanelContent;
  availableContents: { id: PanelContent, name: string }[];
  onContentChange: (newContent: PanelContent) => void;
  children: React.ReactNode;
  onPanelDragStart: (panelId: string, content: PanelContent, e: React.MouseEvent | React.TouchEvent) => void;
  setDropTarget: (target: DropTarget | null) => void;
  draggedPanel: { id: string; content: PanelContent } | null;
  dropTarget: DropTarget | null;
}

const contentTitles: Record<PanelContent, string> = {
  tree: 'Node Diagram',
  controls: 'Edit / Generate',
  viewer: 'Image Viewer',
};

const Panel: React.FC<PanelProps> = ({ 
    id, 
    content, 
    availableContents, 
    onContentChange, 
    children, 
    onPanelDragStart,
    setDropTarget,
    draggedPanel,
    dropTarget
}) => {

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!draggedPanel || draggedPanel.id === id) return;

    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const { width, height } = rect;
    
    const dropZoneSize = 0.25; // 25% of the edge
    let position: DropPosition = 'center';

    if (y < height * dropZoneSize) position = 'top';
    else if (y > height * (1 - dropZoneSize)) position = 'bottom';
    else if (x < width * dropZoneSize) position = 'left';
    else if (x > width * (1 - dropZoneSize)) position = 'right';
    
    setDropTarget({ panelId: id, position });
  };

  const handleMouseLeave = () => {
     if (draggedPanel) {
        setDropTarget(null);
     }
  };

  return (
    <div
      className="w-full h-full flex flex-col bg-gray-800 border border-gray-700/50 rounded-lg overflow-hidden relative"
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
    >
      <header className="flex items-center justify-between pl-3 p-2 bg-gray-900/70 border-b border-gray-700/50 flex-shrink-0">
        <div 
          className="flex-1 cursor-grab"
          onMouseDown={(e) => onPanelDragStart(id, content, e)}
          onTouchStart={(e) => onPanelDragStart(id, content, e)}
        >
          <h3 className="text-sm font-semibold text-gray-300 select-none">{contentTitles[content]}</h3>
        </div>
        <div className="relative group">
          <button className="p-1 rounded-md hover:bg-gray-700" aria-label="Change panel content">
            <ChevronDownIcon className="w-4 h-4 text-gray-400" />
          </button>
          <div className="absolute right-0 mt-1 w-48 bg-gray-800 border border-gray-700 rounded-md shadow-lg z-20 hidden group-hover:block">
            <div className="py-1">
                {availableContents.map(item => (
                <button
                    key={item.id}
                    onClick={() => onContentChange(item.id)}
                    className="block w-full text-left px-3 py-2 text-sm text-gray-300 hover:bg-teal-600 hover:text-white disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-transparent"
                    disabled={item.id === content}
                >
                    {item.name}
                </button>
                ))}
            </div>
          </div>
        </div>
      </header>
      <div className="flex-1 w-full h-full overflow-auto relative">
        {children}
      </div>
      {draggedPanel && draggedPanel.id !== id && (
        <PanelDropZone target={dropTarget} panelId={id} />
      )}
    </div>
  );
};

export default Panel;

================
File: components/PanelDropZone.tsx
================
import React from 'react';
import { DropTarget } from '../types';

interface PanelDropZoneProps {
  target: DropTarget | null;
  panelId: string;
}

const PanelDropZone: React.FC<PanelDropZoneProps> = ({ target, panelId }) => {
  if (!target || target.panelId !== panelId) {
    return null;
  }

  const getPositionStyles = (): React.CSSProperties => {
    switch (target.position) {
      case 'top':
        return { top: 0, left: 0, right: 0, height: '50%' };
      case 'bottom':
        return { bottom: 0, left: 0, right: 0, height: '50%' };
      case 'left':
        return { top: 0, left: 0, bottom: 0, width: '50%' };
      case 'right':
        return { top: 0, right: 0, bottom: 0, width: '50%' };
      case 'center':
        return { top: 0, left: 0, right: 0, bottom: 0 };
      default:
        return {};
    }
  };

  return (
    <div
      className="absolute bg-teal-500/30 border-2 border-dashed border-teal-400 rounded-md transition-all duration-100 pointer-events-none"
      style={getPositionStyles()}
    />
  );
};

export default PanelDropZone;

================
File: components/PromptDiffViewer.tsx
================
import React, { useMemo } from 'react';

interface PromptDiffViewerProps {
    oldText: string;
    newText: string;
}

// A simple diffing algorithm to compare two strings word by word.
// This is a basic implementation of the Longest Common Subsequence algorithm.
const diffWords = (oldStr: string, newStr: string) => {
    const oldWords = oldStr.split(/(\s+)/);
    const newWords = newStr.split(/(\s+)/);
    const dp = Array(oldWords.length + 1).fill(null).map(() => Array(newWords.length + 1).fill(0));

    for (let i = oldWords.length - 1; i >= 0; i--) {
        for (let j = newWords.length - 1; j >= 0; j--) {
            if (oldWords[i] === newWords[j]) {
                dp[i][j] = 1 + dp[i + 1][j + 1];
            } else {
                dp[i][j] = Math.max(dp[i + 1][j], dp[i][j + 1]);
            }
        }
    }

    const parts: { value: string; type: 'common' | 'added' | 'removed' }[] = [];
    let i = 0, j = 0;
    while (i < oldWords.length || j < newWords.length) {
        if (i < oldWords.length && j < newWords.length && oldWords[i] === newWords[j]) {
            parts.push({ value: oldWords[i], type: 'common' });
            i++;
            j++;
        } else if (j < newWords.length && (i === oldWords.length || dp[i][j + 1] >= dp[i + 1][j])) {
            parts.push({ value: newWords[j], type: 'added' });
            j++;
        } else if (i < oldWords.length) {
            parts.push({ value: oldWords[i], type: 'removed' });
            i++;
        }
    }
    return parts;
};


const PromptDiffViewer: React.FC<PromptDiffViewerProps> = ({ oldText, newText }) => {

    const diffResult = useMemo(() => diffWords(oldText, newText), [oldText, newText]);

    return (
        <div className="absolute inset-0 p-2 overflow-y-auto pointer-events-none prompt-diff-viewer">
            {diffResult.map((part, index) => {
                const key = `${part.type}-${part.value}-${index}`;
                if (part.type === 'added') {
                    return <ins key={key}>{part.value}</ins>;
                }
                if (part.type === 'removed') {
                    return <del key={key}>{part.value}</del>;
                }
                return <span key={key}>{part.value}</span>;
            })}
        </div>
    );
};

export default PromptDiffViewer;

================
File: components/Sash.tsx
================
import React, { useRef, useEffect } from 'react';

interface SashProps {
  direction: 'horizontal' | 'vertical';
  onDrag: (delta: number) => void;
}

const Sash: React.FC<SashProps> = ({ direction, onDrag }) => {
  const onDragRef = useRef(onDrag);
  useEffect(() => {
    onDragRef.current = onDrag;
  }, [onDrag]);

  const handleDragStart = (startEvent: React.MouseEvent<HTMLDivElement> | React.TouchEvent<HTMLDivElement>) => {
    startEvent.preventDefault();

    const isTouchEvent = 'touches' in startEvent;

    let lastPos = isTouchEvent
      ? (direction === 'horizontal' ? startEvent.touches[0].clientX : startEvent.touches[0].clientY)
      : 0;

    const handleMouseMove = (moveEvent: MouseEvent) => {
      const delta = direction === 'horizontal' ? moveEvent.movementX : moveEvent.movementY;
      onDragRef.current(delta);
    };

    const handleTouchMove = (moveEvent: TouchEvent) => {
      if (moveEvent.touches.length > 0) {
        const currentPos = direction === 'horizontal' ? moveEvent.touches[0].clientX : moveEvent.touches[0].clientY;
        const delta = currentPos - lastPos;
        onDragRef.current(delta);
        lastPos = currentPos;
      }
    };

    const handleUp = () => {
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleUp);
      document.removeEventListener('touchmove', handleTouchMove);
      document.removeEventListener('touchend', handleUp);
    };

    if (isTouchEvent) {
      document.addEventListener('touchmove', handleTouchMove, { passive: false });
      document.addEventListener('touchend', handleUp);
    } else {
      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleUp);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLDivElement>) => {
    const pixelStep = 10;
    const step = e.shiftKey ? 5 * pixelStep : pixelStep;
    let delta = 0;

    if (direction === 'horizontal') {
        if (e.key === 'ArrowLeft') delta = -step;
        else if (e.key === 'ArrowRight') delta = step;
    } else { // vertical
        if (e.key === 'ArrowUp') delta = -step;
        else if (e.key === 'ArrowDown') delta = step;
    }

    if (delta !== 0) {
        e.preventDefault();
        onDrag(delta);
    }
  };

  const cursor = direction === 'horizontal' ? 'col-resize' : 'row-resize';

  return (
    <div
      onMouseDown={handleDragStart}
      onTouchStart={handleDragStart}
      onKeyDown={handleKeyDown}
      className={`flex-shrink-0 bg-gray-700 hover:bg-teal-500 active:bg-teal-600 transition-colors z-20 focus:outline-none focus:bg-teal-500`}
      style={{
        cursor,
        ...(direction === 'horizontal'
          ? { width: '5px' }
          : { height: '5px' }),
      }}
      tabIndex={0}
      role="separator"
      aria-orientation={direction}
      aria-label={`Resize ${direction}ly`}
    />
  );
};

export default Sash;

================
File: components/SelectedImagesTray.tsx
================
import React from 'react';
import { ImageNode } from '../types';
import { XIcon } from './Icons';

interface SelectedImagesTrayProps {
    selectedNodes: ImageNode[];
    onRemove: (nodeId: string) => void;
    onView: (node: ImageNode) => void;
}

const SelectedImagesTray: React.FC<SelectedImagesTrayProps> = ({ selectedNodes, onRemove, onView }) => {
    if (selectedNodes.length === 0) {
        return (
             <div className="p-2 text-center text-sm text-gray-400 bg-gray-700/50 rounded-lg border border-gray-600">
                Select one or more nodes from the tree to begin.
            </div>
        );
    }

    return (
        <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
                Selected Images ({selectedNodes.length})
            </label>
            <div className="flex flex-wrap gap-2 p-2 bg-gray-700/50 rounded-lg border border-gray-600">
                {selectedNodes.map(node => (
                    <div key={node.id} className="relative group">
                        <button
                            type="button"
                            onClick={() => onView(node)}
                            className="block w-16 h-16 rounded overflow-hidden focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-700 focus:ring-teal-500 transition-shadow shadow-md hover:shadow-lg"
                            aria-label={`View image for prompt: ${node.prompt}`}
                        >
                            <img
                                src={node.imageUrl}
                                alt="Selected"
                                className="w-full h-full object-cover"
                                loading="lazy"
                                decoding="async"
                            />
                        </button>
                         <button
                            onClick={() => onRemove(node.id)}
                            className="absolute -top-2 -right-2 bg-red-600 rounded-full w-6 h-6 flex items-center justify-center text-white shadow-md transition-transform focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-offset-gray-800 focus:ring-red-300 hover:scale-105"
                            aria-label="Remove image"
                        >
                            <XIcon className="w-3.5 h-3.5"/>
                        </button>
                    </div>
                ))}
            </div>
        </div>
    );
};

export default SelectedImagesTray;

================
File: components/SettingsModal.tsx
================
import React, { useState } from 'react';
import { AppSettings, PrompterSettings, ImageGenSettings, HarmCategory, HarmBlockThreshold } from '../types';
import { motion } from 'framer-motion';

interface SettingsModalProps {
    isOpen: boolean;
    onClose: () => void;
    settings: AppSettings;
    onSettingsChange: (settings: AppSettings) => void;
}

type Tab = 'general' | 'prompter' | 'imagegen';

const HARM_CATEGORIES: { key: HarmCategory; label: string }[] = [
    { key: 'HARM_CATEGORY_HARASSMENT', label: 'Harassment' },
    { key: 'HARM_CATEGORY_HATE_SPEECH', label: 'Hate Speech' },
    { key: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', label: 'Sexually Explicit' },
    { key: 'HARM_CATEGORY_DANGEROUS_CONTENT', label: 'Dangerous Content' },
];

const HARM_THRESHOLDS: { key: HarmBlockThreshold; label: string }[] = [
    { key: 'BLOCK_NONE', label: 'Block None' },
    { key: 'BLOCK_ONLY_HIGH', label: 'Block Only High' },
    { key: 'BLOCK_MEDIUM_AND_ABOVE', label: 'Block Medium & Above' },
    { key: 'BLOCK_LOW_AND_ABOVE', label: 'Block Low & Above' },
];

const SettingsModal: React.FC<SettingsModalProps> = ({ isOpen, onClose, settings, onSettingsChange }) => {
    const [activeTab, setActiveTab] = useState<Tab>('general');

    const handlePrompterChange = (newPrompterSettings: Partial<PrompterSettings>) => {
        onSettingsChange({
            ...settings,
            prompter: { ...settings.prompter, ...newPrompterSettings },
        });
    };

    const handleImageGenChange = (newImageGenSettings: Partial<ImageGenSettings>) => {
        onSettingsChange({
            ...settings,
            imageGen: { ...settings.imageGen, ...newImageGenSettings },
        });
    };

    if (!isOpen) return null;

    const renderTabContent = () => {
        switch (activeTab) {
            case 'general':
                return <GeneralSettingsPanel />;
            case 'prompter':
                return <PrompterSettingsPanel settings={settings.prompter} onChange={handlePrompterChange} />;
            case 'imagegen':
                return <ImageGenSettingsPanel settings={settings.imageGen} onChange={handleImageGenChange} />;
        }
    };

    return (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 backdrop-blur-sm" onClick={onClose}>
            <motion.div 
                className="bg-gray-800 rounded-lg shadow-xl w-full max-w-2xl mx-4 flex flex-col max-h-[90vh]" 
                onClick={e => e.stopPropagation()}
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.2 }}
                role="dialog"
                aria-modal="true"
            >
                <div className="flex justify-between items-center p-4 border-b border-gray-700">
                    <h2 className="text-xl font-bold text-gray-100">Settings</h2>
                    <button onClick={onClose} className="text-gray-400 hover:text-white text-2xl leading-none">&times;</button>
                </div>
                <div className="flex border-b border-gray-700">
                    <TabButton name="General" tab="general" activeTab={activeTab} setActiveTab={setActiveTab} />
                    <TabButton name="Prompter" tab="prompter" activeTab={activeTab} setActiveTab={setActiveTab} />
                    <TabButton name="Image Gen" tab="imagegen" activeTab={activeTab} setActiveTab={setActiveTab} />
                </div>
                <div className="p-6 overflow-y-auto">
                    {renderTabContent()}
                </div>
            </motion.div>
        </div>
    );
};

const TabButton: React.FC<{ name: string, tab: Tab, activeTab: Tab, setActiveTab: (tab: Tab) => void }> = ({ name, tab, activeTab, setActiveTab }) => (
    <button
        onClick={() => setActiveTab(tab)}
        className={`px-4 py-2 text-sm font-medium transition-colors ${activeTab === tab ? 'border-b-2 border-teal-400 text-teal-400' : 'text-gray-400 hover:bg-gray-700/50'}`}
    >
        {name}
    </button>
);

const GeneralSettingsPanel: React.FC = () => (
    <div className="space-y-6">
        <div>
            <h3 className="text-lg font-semibold text-gray-200 mb-3 border-b border-gray-700 pb-2">API Key Management</h3>
            <div className="bg-gray-700/50 p-4 rounded-lg space-y-3">
                 <div>
                     <label htmlFor="api-key-input" className="block text-sm font-medium text-gray-300 mb-1">Google AI API Key</label>
                     <input 
                        id="api-key-input"
                        type="text"
                        disabled
                        className="w-full bg-gray-900/50 border border-gray-600 rounded-lg p-2 text-gray-400 font-mono cursor-not-allowed text-base"
                        value="Loaded from .env (VITE_GEMINI_API_KEY)"
                     />
                </div>
                <p className="text-sm text-gray-300">
                    For security, your API key is managed via an environment file (`.env.local`) using the `VITE_GEMINI_API_KEY` variable.
                </p>
                <p className="text-xs text-gray-400">
                    This is a best practice to prevent exposing your secret key in the browser. You do not need to, and cannot, enter it here. The application will use the key provided in its environment.
                </p>
            </div>
        </div>
        <div>
            <h3 className="text-lg font-semibold text-gray-200 mb-3 border-b border-gray-700 pb-2">Account Sync</h3>
             <div className="bg-gray-700/50 p-4 rounded-lg">
                <p className="text-sm text-gray-300">
                    Account sign-in and cloud synchronization of settings are great features for a production-level application!
                </p>
                <p className="text-xs text-gray-400 mt-2">
                    However, they require a backend server and database, which this client-side-only application does not have.
                </p>
            </div>
        </div>
    </div>
);

const ImageGenSettingsPanel: React.FC<{ settings: ImageGenSettings, onChange: (s: Partial<ImageGenSettings>) => void }> = ({ settings, onChange }) => {
    
    const handleSafetyChange = (category: HarmCategory, threshold: HarmBlockThreshold) => {
        const newSafetySettings = settings.safetySettings.map(setting =>
            setting.category === category
                ? { ...setting, threshold }
                : setting
        );
        onChange({ safetySettings: newSafetySettings });
    };

    return (
        <div className="space-y-6">
            <div>
                <h3 className="text-lg font-semibold text-gray-200 mb-3 border-b border-gray-700 pb-2">Content Safety Settings</h3>
                <p className="text-sm text-gray-400 mb-4">
                    Adjust the content safety filters for image generation. Setting these to 'Block None' may result in less filtering but could generate content that is sensitive or blocked by policy. Use with caution.
                </p>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {HARM_CATEGORIES.map(({ key, label }) => (
                        <div key={key}>
                            <label htmlFor={`safety-${key}`} className="block text-sm font-medium text-gray-300 mb-1">{label}</label>
                            <select
                                id={`safety-${key}`}
                                value={settings.safetySettings.find(s => s.category === key)?.threshold || 'BLOCK_NONE'}
                                onChange={(e) => handleSafetyChange(key, e.target.value as HarmBlockThreshold)}
                                className="w-full bg-gray-700/80 border border-gray-600 rounded-lg p-2 text-white focus:ring-2 focus:ring-teal-500 transition text-base"
                            >
                                {HARM_THRESHOLDS.map(threshold => (
                                    <option key={threshold.key} value={threshold.key}>{threshold.label}</option>
                                ))}
                            </select>
                        </div>
                    ))}
                </div>
            </div>
        </div>
    );
};

const PrompterSettingsPanel: React.FC<{ settings: PrompterSettings, onChange: (s: Partial<PrompterSettings>) => void }> = ({ settings, onChange }) => {
    return (
        <div className="space-y-6">
            <div>
                <h3 className="text-lg font-semibold text-gray-200 mb-3 border-b border-gray-700 pb-2">Custom Instructions</h3>
                <textarea
                    rows={4}
                    className="w-full bg-gray-700/80 border border-gray-600 rounded-lg p-2 text-white focus:ring-2 focus:ring-teal-500 transition text-base"
                    placeholder="e.g., Always generate prompts in a cinematic style."
                    value={settings.customInstructions}
                    onChange={e => onChange({ customInstructions: e.target.value })}
                />
                 <p className="text-xs text-gray-400 mt-1">These instructions are added to every AI prompt generation request.</p>
            </div>
            
            <div>
                 <h3 className="text-lg font-semibold text-gray-200 mb-3 border-b border-gray-700 pb-2">Advanced Settings</h3>
                 <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <SettingSlider
                        label="Temperature"
                        value={settings.temperature}
                        min={0} max={1} step={0.05}
                        onChange={v => onChange({ temperature: v })}
                        description="Controls randomness. Higher values are more creative."
                    />
                     <SettingInput
                        label="Top-K"
                        type="number"
                        value={settings.topK}
                        onChange={v => onChange({ topK: Number(v) })}
                        description="Limits the token selection pool."
                     />
                     <SettingSlider
                        label="Top-P"
                        value={settings.topP}
                        min={0} max={1} step={0.05}
                        onChange={v => onChange({ topP: v })}
                        description="Nucleus sampling. Considers tokens with this probability mass."
                    />
                 </div>
            </div>
            <div className="text-xs text-gray-500">Note: Safety settings and token limits are placeholders for future implementation.</div>

        </div>
    )
}

const SettingSlider: React.FC<{ label: string, value: number, min: number, max: number, step: number, onChange: (v: number) => void, description: string }> = 
({label, value, min, max, step, onChange, description}) => (
    <div>
        <label className="block text-sm font-medium text-gray-300">{label} <span className="font-mono text-teal-400">{value}</span></label>
        <input
            type="range"
            min={min} max={max} step={step} value={value}
            onChange={e => onChange(Number(e.target.value))}
            className="w-full h-2 bg-gray-600 rounded-lg appearance-none cursor-pointer accent-teal-500"
        />
        <p className="text-xs text-gray-400 mt-1">{description}</p>
    </div>
);

const SettingInput: React.FC<{ label: string, value: number | string, type: string, onChange: (v: string | number) => void, description: string }> = 
({label, value, type, onChange, description}) => (
    <div>
        <label className="block text-sm font-medium text-gray-300">{label}</label>
        <input
            type={type}
            value={value}
            onChange={e => onChange(e.target.value)}
            className="w-full bg-gray-700/80 border border-gray-600 rounded-lg p-2 text-white focus:ring-2 focus:ring-teal-500 transition text-base"
        />
        <p className="text-xs text-gray-400 mt-1">{description}</p>
    </div>
);


export default SettingsModal;

================
File: hooks/useMediaQuery.ts
================
import { useState, useEffect } from 'react';

const useMediaQuery = (query: string): boolean => {
  const getMatches = (query: string): boolean => {
    // Prevents SSR issues
    if (typeof window !== 'undefined') {
      return window.matchMedia(query).matches;
    }
    return false;
  };

  const [matches, setMatches] = useState<boolean>(getMatches(query));

  useEffect(() => {
    const mediaQueryList = window.matchMedia(query);
    const handleChange = () => setMatches(mediaQueryList.matches);

    // Initial check
    handleChange();
    
    // Listen for changes
    mediaQueryList.addEventListener('change', handleChange);

    return () => {
      mediaQueryList.removeEventListener('change', handleChange);
    };
  }, [query]);

  return matches;
};

export default useMediaQuery;

================
File: hooks/useResizeObserver.ts
================
import { useState, useEffect } from 'react';

const useResizeObserver = <T extends HTMLElement>(ref: React.RefObject<T>) => {
    const [dimensions, setDimensions] = useState<DOMRectReadOnly | null>(null);

    useEffect(() => {
        const observeTarget = ref.current;
        if (!observeTarget) return;

        const resizeObserver = new ResizeObserver((entries) => {
            entries.forEach(entry => {
                setDimensions(entry.contentRect);
            });
        });

        resizeObserver.observe(observeTarget);

        return () => {
            resizeObserver.disconnect();
        };
    }, [ref]);

    return dimensions;
};

export default useResizeObserver;

================
File: scripts/dev-tailscale.sh
================
#!/usr/bin/env bash
set -euo pipefail

# Determine a likely Tailscale IP (fallback to primary LAN IP)
TS_IP=""
if command -v tailscale >/dev/null 2>&1; then
  set +e
  TS_IP=$(tailscale ip -4 2>/dev/null | head -n1)
  set -e
fi

if [[ -z "${TS_IP}" ]]; then
  # macOS fallback: try common interfaces (en0 first)
  if command -v ipconfig >/dev/null 2>&1; then
    TS_IP=$(ipconfig getifaddr en0 2>/dev/null || true)
    if [[ -z "${TS_IP}" ]]; then
      TS_IP=$(ipconfig getifaddr en1 2>/dev/null || true)
    fi
  fi
fi

if [[ -z "${TS_IP}" ]]; then
  # Generic fallback
  TS_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

export VITE_HOST=public
if [[ -n "${TS_IP}" ]]; then
  export VITE_HMR_HOST="${TS_IP}"
fi

echo "Running Vite dev server bound to 0.0.0.0 (public)"
if [[ -n "${TS_IP}" ]]; then
  echo "Hint: access via http://${TS_IP}:${VITE_PORT:-5173} (Tailscale/LAN)"
fi

# Force bind to 0.0.0.0 and keep chosen port
exec vite --host 0.0.0.0 --port "${VITE_PORT:-5173}" "$@"

================
File: services/geminiService.ts
================
import { GoogleGenAI, Modality, GenerateContentResponse, Type } from "@google/genai";
// FIX: Import HarmCategory and HarmBlockThreshold from local types to match the rest of the app
import { PrompterSettings, HarmCategory, HarmBlockThreshold } from '../types';

// Prefer Vite-style env vars exposed to the client. Fallbacks kept for dev overrides.
const API_KEY = (import.meta as any).env?.VITE_GEMINI_API_KEY || (import.meta as any).env?.VITE_API_KEY;

if (!API_KEY) {
    // Provide a clear message in dev if the key is missing.
    // Ensure .env.local contains VITE_GEMINI_API_KEY=... and restart dev server.
    console.warn('Gemini API key missing. Set VITE_GEMINI_API_KEY in .env.local');
}

const ai = new GoogleGenAI({ apiKey: API_KEY });
const textModel = 'gemini-2.5-flash';
const imageModel = 'gemini-2.5-flash-image-preview';

const getVariationInstructions = (level: number): string => {
    switch (level) {
        case 1:
            return "Generate very subtle variations. Focus on minor details like lighting, slight texture changes, or minimal adjustments to object placement. The core concept and composition must remain almost identical to the original.";
        case 2:
            return "Introduce noticeable but conservative changes. You can alter secondary elements, adjust the time of day, or modify the color palette slightly. The main subject and overall mood should be preserved.";
        case 3:
            return "Create moderately distinct variations. Feel free to change the artistic style (e.g., from photorealistic to painterly), the primary background elements, or the subject's pose. The core idea should still be recognizable.";
        case 4:
            return "Produce significant and creative variations. Reimagine the scene with different core components, introduce new, unexpected elements, or drastically change the theme or genre while keeping a conceptual link to the original.";
        case 5:
            return "Generate wild and highly imaginative variations. Take the core essence of the prompt and/or image and create something radically different and surprising. Push the boundaries of creativity; the connection to the original can be abstract or thematic.";
        default:
            return "Create moderately distinct variations.";
    }
}

/**
 * Generates creative variations of a base prompt, using source images as context.
 */
export const generatePromptVariations = async (
    basePrompt: string,
    count: number,
    images: { data: string; mimeType: string }[],
    variationLevel: number,
    settings: PrompterSettings
): Promise<string[]> => {
    try {
        const imageParts = images.map(image => ({
            inlineData: {
                data: image.data,
                mimeType: image.mimeType
            }
        }));

        const variationInstruction = getVariationInstructions(variationLevel);

        let instructions = `You are a creative assistant for an AI image generation tool. Your task is to analyze the provided image(s) and the user's base prompt to generate ${count} inspiring and diverse new prompts.

The user's base prompt is: "${basePrompt}"

**Creative Guidance:** ${variationInstruction}

Your generated prompts should be creative variations that explore different artistic styles, moods, compositions, or details, while staying relevant to the core subject of the image(s) and the user's initial idea. Do not just add simple modifiers; suggest meaningful and imaginative changes.
`;

        if (settings.customInstructions) {
            instructions += `\n**Important User-Provided Instructions:**\n${settings.customInstructions}`;
        }

        instructions += `\nReturn the result as a JSON object with a single key "prompts" containing an array of ${count} strings.`;


        const textPart = { text: instructions };
        
        const response: GenerateContentResponse = await ai.models.generateContent({
            model: textModel,
            contents: {
                parts: [...imageParts, textPart]
            },
            config: {
                responseMimeType: 'application/json',
                responseSchema: {
                    type: Type.OBJECT,
                    properties: {
                        prompts: {
                            type: Type.ARRAY,
                            items: { type: Type.STRING }
                        }
                    }
                },
                temperature: settings.temperature,
                topK: settings.topK,
                topP: settings.topP,
                // maxOutputTokens can be added if useTokenLimit is true
            }
        });
        
        const jsonResponse = JSON.parse(response.text);
        if (jsonResponse.prompts && Array.isArray(jsonResponse.prompts)) {
            return jsonResponse.prompts;
        }
        throw new Error('Invalid format for prompt variations');

    } catch (error) {
        console.error("Error generating prompt variations:", error);
        // Fallback to simpler variations if the AI fails
        return Array(count).fill(basePrompt).map((p, i) => `${p}, variation ${i + 1}`);
    }
};

/**
 * Generates image variations based on a prompt and input images.
 */
export const generateImageVariations = async (
    prompt: string, 
    images: { data: string; mimeType: string }[],
    // FIX: Changed safetySettings from a Record to an array of objects to match the Gemini API.
    safetySettings: { category: HarmCategory, threshold: HarmBlockThreshold }[],
    aspectRatio: string
): Promise<string[]> => {
    const imageParts = images.map(image => ({
        inlineData: {
            data: image.data,
            mimeType: image.mimeType
        }
    }));

    let instructionPrompt = `Based on the provided image(s), create a new image with the following change or theme: ${prompt}`;
    if (aspectRatio && aspectRatio !== 'auto') {
        // Use "to" for better natural language phrasing
        instructionPrompt += ` The new image should have an aspect ratio of ${aspectRatio.replace(':', ' to ')}.`;
    }

    const textPart = { text: instructionPrompt };

    try {
        const response: GenerateContentResponse = await ai.models.generateContent({
            model: imageModel,
            contents: {
                parts: [...imageParts, textPart]
            },
            config: {
                responseModalities: [Modality.IMAGE, Modality.TEXT],
                // FIX: The `safetySettings` config is not supported for the 'gemini-2.5-flash-image-preview' model used for image editing.
                // safetySettings,
            },
        });

        const generatedImages: string[] = [];
        const candidate = response.candidates?.[0];

        if (candidate?.content?.parts) {
            for (const part of candidate.content.parts) {
                if (part.inlineData) {
                    const imageUrl = `data:${part.inlineData.mimeType};base64,${part.inlineData.data}`;
                    generatedImages.push(imageUrl);
                }
            }
        }
        
        if (generatedImages.length === 0) {
            const finishReason = candidate?.finishReason;
            const safetyRatings = candidate?.safetyRatings;
            let message = "No image was generated by the API.";
            if (finishReason === 'SAFETY') {
                const blockedRatings = safetyRatings?.filter(r => r.blocked).map(r => r.category.replace('HARM_CATEGORY_', '')).join(', ');
                message = `Blocked for: ${blockedRatings || 'Safety'}. Adjust prompt or safety levels.`;
            } else if (finishReason && finishReason !== 'STOP') {
                message = `Generation failed due to: ${finishReason}.`;
            } else {
                 message += " The prompt may have been blocked or resulted in no output.";
            }
            throw new Error(message);
        }
        
        return generatedImages;
    } catch (error) {
        console.error("Error generating image variations:", error);
        throw error;
    }
};


/**
 * Enhances a user's prompt using a detailed system instruction for optimization.
 */
export const enhancePrompt = async (
    userPrompt: string,
    images: { data: string; mimeType: string }[]
): Promise<string> => {
    
    const systemInstruction = `
ROLE
You are a just-in-time Prompt Optimizer that integrates USER_PROMPT and optional CONTEXT_IMAGES, then outputs one compact, production-ready image prompt. You transform brief or messy ideas into precise, cinematic directives using scene description, camera language, and exact edit instructions. No meta commentary, no headings, no quotes—output only the final improved prompt.

INPUTS
• USER_PROMPT: raw text from the user (optional if images only)
• CONTEXT_IMAGES: zero or more reference images provided with the request
• MODE: Text→Image | Image→Image | Image Edit | Multi-image Fusion
• OPTIONAL: aspect ratio, style references, banned elements

INPUT PAYLOAD TYPES
• Text only
• Image only
• Text + Image(s)

LENGTH POLICY
Target budgets by mode and payload:
• Text→Image (text only): 90–140 target; hard cap 160 words or 1,000 chars
• Text→Image (text+image): 70–120 target; hard cap 140 words or 950 chars
• Image→Image (image only): 60–110 target; hard cap 130 words or 900 chars
• Image→Image (text+image): 70–120 target; hard cap 140 words or 950 chars
• Image Edit: 50–90 target; hard cap 120 words or 750 chars
• Multi-image Fusion: 90–150 target; hard cap 170 words or 1,050 chars
General rules:
• One scene only. Max 2 subordinate clauses.
• Per category (shot/angle/lens/lighting/composition/style), pick 1 primary and at most 1 secondary.
• Max 3 proper nouns. Max 3 style cues. Max 3 “avoid” items.
• Prefer vivid sentences over lists; compress adjectives with hyphens.
• If over cap: strip redundant adjectives → collapse lists → drop lowest-priority style cues → simplify lighting.

CORE MODES
• Text→Image: Generate from description
• Image→Image: Global transformation of provided source
• Image Edit: Local, surgical changes
• Multi-image Fusion: Combine 2–3 inputs coherently

PROMPT CONSTRUCTION
1) Narrative Spine: Subject → action → environment → time → mood. Anchor from USER_PROMPT and/or CONTEXT_IMAGES.
2) Photoreal Elements: weave naturally, 1–2 each (shot, angle, lens, DOF, lighting, composition, materials, color).
3) Stylization Elements: only if implied by prompt/images (style family, line, shading, palette, background).
4) Editing Principles: “Change only: [target]. Do not alter: [protected]. Operation: [sequence].”
5) Fusion Method: “Extract from A, place in B, apply texture from C. Match perspective/scale/lighting/grade.”
6) Quality Enhancers: pick 2–3 (micro-detail, accurate lighting, reflections, depth, perspective, material accuracy).

VISION CONTEXT POLICY
When CONTEXT_IMAGES exist:
A) Image Audit:
• Identify subjects, anchors, scene, camera cues, lighting, palette, materials, text/logos.
B) Alignment Rules:
• Image facts outrank text for what exists; text outranks image for intent. Preserve anchors unless replaced.
• Sparse text → fill with neutral defaults inferred from image (eye level, natural light).
C) Brevity:
• Omit obvious content from images; focus on deltas, intent, and enhancements.

SPECIALIZED APPROACHES
• Product: hero lighting, material detail
• Minimalist: negative space, directional light
• Sequential Art: style continuity
• Text/Logos: integrated, high contrast
• Overlays: preserve surface/lighting

ENRICHMENT PATTERNS
Person: age, ethnicity, build, garments, expression
Landscape: landform, vegetation, weather, time
Product: material, finish, imperfections, scale
Building: style, materials, weathering
Animal: species, texture, pose, environment
Food: cuisine, method, garnish, plating

CORE PRINCIPLES
1) Preserve anchors (faces, logos, props)
2) Iterative refinement: base → add → refine
3) Use technical/film terms
4) Single light logic
5) Material accuracy

NANO BANANA TUNING
• One tight paragraph, no lists
• Use concrete nouns, unambiguous camera/lighting
• Negative prompts ≤3 items
• Aspect ratio only if provided
• With images: bias toward delta-only wording

ALGORITHM
1) Detect MODE from USER_PROMPT and CONTEXT_IMAGES.
2) Run Image Audit if images provided.
3) Extract mandatory facts in priority: anchors → subject/action → env → time → lighting → camera → materials → style → color → constraints → edits/fusion.
4) Resolve conflicts: images = state, text = intent. Drop contradictions silently unless explicit replace/add/remove.
5) Build 2–5 sentence spine, plus edit/fusion line if needed.
6) Add 1 impactful cue per category.
7) Enforce length policy; compress if needed.
8) Output only final improved prompt.

CONFLICT HANDLING
• If text conflicts internally: keep anchors + subject/action, drop later conflicts.
• If text conflicts with images: image = ground truth, text = instructions. Use “replace/add/remove” syntax.
• If sparse: default to neutral photographic norms; no unverifiable specifics.

OUTPUT FORMAT
• Text only or Text+Image: one compact paragraph; add short edit sentences if requested.
• Image only: one compact paragraph (default Image→Image).
• Multi-image Fusion: one compact paragraph + one fusion sentence.
• No headings, no brackets, no meta notes.
`;

    try {
        const imageParts = images.map(image => ({
            inlineData: {
                data: image.data,
                mimeType: image.mimeType
            }
        }));

        const hasImages = images.length > 0;
        const hasText = userPrompt.trim().length > 0;

        let mode = "Text->Image";
        if (hasImages && !hasText) mode = "Image->Image";
        else if (hasImages && hasText) mode = "Text->Image";

        const userRequest = `
NOW PERFORM ON INPUT
USER_PROMPT: ${userPrompt || '(No prompt text provided)'}
CONTEXT_IMAGES: ${hasImages ? `${images.length} image(s) provided` : 'None'}
MODE: ${mode}

Produce the improved prompt now.
`;

        const textPart = { text: userRequest };
        
        const response = await ai.models.generateContent({
            model: textModel,
            contents: {
                parts: [...imageParts, textPart]
            },
            config: {
                systemInstruction,
                temperature: 0.5,
            }
        });
        
        return response.text.trim();
    } catch (error) {
        console.error("Error enhancing prompt:", error);
        throw new Error("Failed to enhance prompt. Please try again.");
    }
};

================
File: utils/imageUtils.ts
================
export const fileToGenerativePart = async (file: File) => {
    const base64EncodedDataPromise = new Promise<string>((resolve) => {
        const reader = new FileReader();
        reader.onloadend = () => {
            if (typeof reader.result === 'string') {
                resolve(reader.result.split(',')[1]);
            }
        };
        reader.readAsDataURL(file);
    });

    return {
        inlineData: {
            data: await base64EncodedDataPromise,
            mimeType: file.type,
        },
    };
};

================
File: utils/layoutUtils.ts
================
import { Layout, Panel, SplitContainer, PanelContent, DropPosition, DropTarget } from '../types';

/**
 * Recursively finds a node and its parent within the layout tree.
 */
const findNodeWithParent = (
  layout: Layout,
  nodeId: string,
  parent: SplitContainer | null = null
): { node: Layout; parent: SplitContainer | null } | null => {
  if (layout.id === nodeId) {
    return { node: layout, parent };
  }
  if (layout.type === 'split') {
    return (
      findNodeWithParent(layout.children[0], nodeId, layout) ||
      findNodeWithParent(layout.children[1], nodeId, layout)
    );
  }
  return null;
};

/**
 * Immutably swaps the content of two panels in the layout tree.
 * Can also be used to just change one panel's content if the second ID is actually a content type.
 */
export const swapPanelContents = (
  layout: Layout,
  panelId1: string,
  panelId2OrContent: string
): Layout => {
  let panel1: Panel | null = null;
  let panel2: Panel | null = null;
  
  const findPanels = (node: Layout) => {
      if(node.type === 'panel') {
          if (node.id === panelId1) panel1 = node;
          if (node.id === panelId2OrContent) panel2 = node;
      } else {
          findPanels(node.children[0]);
          findPanels(node.children[1]);
      }
  }
  findPanels(layout);

  const transform = (node: Layout): Layout => {
    if (node.type === 'panel') {
        if(panel1 && panel2 && node.id === panel1.id) return { ...node, content: panel2.content };
        if(panel1 && panel2 && node.id === panel2.id) return { ...node, content: panel1.content };
        if(panel1 && !panel2 && node.id === panel1.id) return { ...node, content: panelId2OrContent as PanelContent };
    }
    if (node.type === 'split') {
        return {
            ...node,
            children: [transform(node.children[0]), transform(node.children[1])]
        }
    }
    return node;
  };

  return transform(layout);
};


/**
 * Immutably removes a node from the layout tree, collapsing its parent SplitContainer if necessary.
 */
export const removeNodeFromLayout = (
  layout: Layout,
  nodeId: string
): { newRoot: Layout | null; removedNode: Panel | null } => {
  let removedNode: Panel | null = null;

  const recurse = (node: Layout): Layout | null => {
    if (node.id === nodeId) {
      if (node.type === 'panel') removedNode = node;
      return null; // Remove this node
    }

    if (node.type === 'split') {
      const newChild1 = recurse(node.children[0]);
      const newChild2 = recurse(node.children[1]);

      if (!newChild1 && !newChild2) return null; // Both children removed, remove split
      if (!newChild1) return newChild2; // Child 1 removed, promote child 2
      if (!newChild2) return newChild1; // Child 2 removed, promote child 1

      // Nothing changed for this node's children
      return { ...node, children: [newChild1, newChild2] };
    }

    return node;
  };

  const newRoot = recurse(layout);
  return { newRoot, removedNode };
};


/**
 * Immutably inserts a node into the layout tree by splitting a target panel.
 */
export const insertNodeIntoLayout = (
    layout: Layout,
    draggedPanel: Panel,
    targetPanelId: string,
    position: DropPosition
): Layout => {
    const recurse = (node: Layout): Layout => {
        if (node.id !== targetPanelId) {
            if (node.type === 'split') {
                return { ...node, children: [recurse(node.children[0]), recurse(node.children[1])] };
            }
            return node;
        }

        // This is the target node, replace it with a split
        if (node.type === 'panel') {
            const newSplit: SplitContainer = {
                id: crypto.randomUUID(),
                type: 'split',
                direction: position === 'left' || position === 'right' ? 'horizontal' : 'vertical',
                sizes: [50, 50],
                children: 
                    position === 'left' || position === 'top' 
                    ? [draggedPanel, node] 
                    : [node, draggedPanel],
            };
            return newSplit;
        }
        return node; // Should not happen if target is always a panel
    };

    return recurse(layout);
}

================
File: .gitignore
================
# Logs
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*
lerna-debug.log*

node_modules
dist
dist-ssr
*.local

# Editor directories and files
.vscode/*
!.vscode/extensions.json
.idea
.DS_Store
*.suo
*.ntvs*
*.njsproj
*.sln
*.sw?

================
File: AGENTS.md
================
# AGENTS.md — Guidance for Agents Working in gemini-image-weaver

This file sets conventions and tips for anyone (human or agent) contributing to this repo. Its scope is the entire repository.

## Tech Stack
- React + TypeScript (Vite)
- D3 v7 for the interactive node diagram (ImageTree)
- react-toastify for notifications
- Google GenAI client in `services/`

## Run / Build
- Dev: `npm run dev` → Vite at http://localhost:5173 (default)
- Build: `npm run build`
- Preview: `npm run preview`
- Env: set `VITE_GEMINI_API_KEY` in `.env.local` (restart dev server after editing env files)

## Project Layout (high level)
- `App.tsx`: top-level state and layout orchestration
- `components/`
  - `ImageTree.tsx`: the D3-based node map (pan/zoom/drag)
  - `ImageViewer.tsx`, `FullScreenImageViewer.tsx`: viewing UI
  - `ControlPanel.tsx`: prompt + generation controls
  - `DockingLayout.tsx`, `Panel.tsx`, `Sash.tsx`: resizable/dockable panels
- `hooks/`: small utilities (e.g., `useResizeObserver`)
- `services/`: GenAI integrations
- `utils/`: layout + misc helpers
- `types.ts`: shared types

## Coding Conventions
- Prefer small, focused React components and hooks.
- Keep state lifting minimal; co-locate state unless shared broadly.
- TypeScript: be explicit with prop and return types; avoid `any`.
- Diffs should be minimal and scoped; avoid drive‑by refactors.
- Use functional updates (`setState(prev => ...)`) when derived from prior state.
- Avoid adding new deps unless clearly necessary.

## Node Map Guidelines
- The node map lives in `components/ImageTree.tsx`.
- Implementation is a React-only freeform canvas:
  - One CSS-transformed `content` div for pan/zoom
  - An SVG inside `content` draws connectors
  - Absolutely positioned node tiles inside `content` handle dragging via Pointer Events
- Panning/zooming: CSS `transform` on the `content` element with `transform-origin: 0 0`.
- Nodes: `.graph-node` tiles; dragging updates in-memory positions; edges read from the same position store.
- Links: drawn between node centers in the SVG so they remain tethered under all transforms.

## Interaction Rules
- Click: selects node; Cmd/Ctrl+Click toggles multi-select.
- Drag on a node: drags that node (simulation fixes/unfixes `fx/fy`).
- Drag on empty canvas: pans the map.
- Wheel / trackpad: zooms the map.

## Testing Changes Locally
- After edits in `ImageTree.tsx`, verify:
  - Dragging a node moves only that node and continues simulation.
  - Dragging on empty space pans the entire map smoothly.
  - Wheel zoom scales both nodes and link lines together.
  - Selection glow/border reacts to state updates.

## Agent Workflow
- Plan → Verify → Act → Test → Report.
- Prefer patch-based edits; keep changes minimal and well-scoped.
- If you need to change files outside your current scope, stop and note follow-ups.
- When touching D3 code:
  - Don’t mix HTML `attr('transform', ...)` with CSS transforms; prefer CSS.
  - Use regular functions (not arrows) where D3 needs `this` to be the element.
  - Keep `useRef` values nullable and check before use.

## Accessibility & UX
- Buttons must have discernible labels and focus rings.
- Don’t rely on color alone for selected state (we also use glow/box-shadow).
- Prefer click targets ≥ 32px where feasible.

## Performance Tips
- Avoid unnecessary React re-renders; memoize where it helps (`useMemo`, `useCallback`).
- Lazy-load images and remove/replace ghost placeholders on `img.onload`.
- Keep D3 joins stable by keying on `id`.

## CI / Linting
- No formal CI here yet. Keep PRs small and reviewable.
- Run the dev server and do a quick manual pass before pushing.

## Known Gotchas
- Zoom/pan must be applied via CSS transform on the HTML container; using SVG `attr('transform')` on a `<div>` will not work.
- D3 drag + zoom can conflict; the zoom filter checks for `.node` to allow node drags while still enabling canvas pan.

## Contact / Ownership
- Primary owner: Kosta
- If you discover necessary cross-cutting refactors, open an issue first and propose scope/plan.

================
File: App.tsx
================
import React, { useState, useCallback, useMemo, useEffect, useRef } from 'react';
import { ToastContainer, toast } from 'react-toastify';
import { ImageNode, AppSettings, Layout, PanelContent, DropTarget, GhostNode } from './types';
import { generatePromptVariations, generateImageVariations } from './services/geminiService';
import useMediaQuery from './hooks/useMediaQuery';
import { removeNodeFromLayout, insertNodeIntoLayout, swapPanelContents } from './utils/layoutUtils';

import ControlPanel from './components/ControlPanel';
import ImageTree from './components/ImageTree';
import ErrorBoundary from './components/ErrorBoundary';
import ImageViewer from './components/ImageViewer';
import HistoryViewer from './components/HistoryViewer';
import SettingsModal from './components/SettingsModal';
import Loader from './components/Loader';
import DockingLayout from './components/DockingLayout';
import Panel from './components/Panel';
import DragGhost from './components/DragGhost';
import FullScreenImageViewer from './components/FullScreenImageViewer';
import DropZoneOverlay from './components/DropZoneOverlay';


const DEFAULT_SETTINGS: AppSettings = {
    prompter: {
        safety: 'BLOCK_MEDIUM_AND_ABOVE',
        outputLength: 'medium',
        useTokenLimit: false,
        maxTokens: 1024,
        customInstructions: '',
        temperature: 0.8,
        topK: 40,
        topP: 0.95,
    },
    imageGen: {
        safetySettings: [
            { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_NONE' },
            { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_NONE' },
            { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_NONE' },
            { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_NONE' },
        ],
    },
};

const initialLayout: Layout = {
  id: 'root-split',
  type: 'split',
  direction: 'horizontal',
  sizes: [65, 35],
  children: [
    { id: 'panel-tree', type: 'panel', content: 'tree' },
    {
      id: 'right-split',
      type: 'split',
      direction: 'vertical',
      sizes: [50, 50],
      children: [
        { id: 'panel-controls', type: 'panel', content: 'controls' },
        { id: 'panel-viewer', type: 'panel', content: 'viewer' },
      ],
    },
  ],
};

const availablePanelContents: { id: PanelContent, name: string }[] = [
    { id: 'tree', name: 'Node Diagram' },
    { id: 'controls', name: 'Controls' },
    { id: 'viewer', name: 'Image Viewer' },
];

const MAX_IMAGE_SIZE_BYTES = 25 * 1024 * 1024; // 25MB guard for uploads

const validateImageFile = (file: File): boolean => {
    if (!file.type.startsWith('image/')) {
        toast.error('Please choose an image file.');
        return false;
    }
    if (file.size > MAX_IMAGE_SIZE_BYTES) {
        const mb = (MAX_IMAGE_SIZE_BYTES / (1024 * 1024)).toFixed(0);
        toast.error(`Images must be smaller than ${mb}MB. Try a smaller file.`);
        return false;
    }
    if (file.size === 0) {
        toast.error('The selected file appears to be empty.');
        return false;
    }
    return true;
};


const dataUrlToBase64 = (dataUrl: string): { data: string, mimeType: string } => {
    const parts = dataUrl.split(',');
    const mimeType = parts[0].match(/:(.*?);/)?.[1] || 'image/png';
    const data = parts[1];
    return { data, mimeType };
};

function App() {
    const [nodes, setNodes] = useState<ImageNode[]>([]);
    const [ghostNodes, setGhostNodes] = useState<GhostNode[]>([]);
    const [selectedNodeIds, setSelectedNodeIds] = useState<Set<string>>(new Set());
    const [viewedNodeId, setViewedNodeId] = useState<string | null>(null);
    const [fullScreenNodeId, setFullScreenNodeId] = useState<string | null>(null);
    const [historyNode, setHistoryNode] = useState<ImageNode | null>(null);
    
    const [isLoading, setIsLoading] = useState(false);
    const [loaderMessage, setLoaderMessage] = useState('');
    const [isGenerating, setIsGenerating] = useState(false);

    const [isSelectMode, setIsSelectMode] = useState(false);
    const [isSettingsOpen, setIsSettingsOpen] = useState(false);
    const [settings, setSettings] = useState<AppSettings>(DEFAULT_SETTINGS);
    const [layout, setLayout] = useState<Layout>(initialLayout);
    const [mobileTopPanelHeight, setMobileTopPanelHeight] = useState(66.67);

    // Drag and Drop State
    const [draggedPanel, setDraggedPanel] = useState<{ id: string; content: PanelContent } | null>(null);
    const [dropTarget, setDropTarget] = useState<DropTarget | null>(null);
    const [ghostPosition, setGhostPosition] = useState<{ x: number, y: number } | null>(null);
    const dragStartOffset = useRef<{x: number, y: number}>({ x: 0, y: 0 });

    // Global file drop state
    const [isDraggingFile, setIsDraggingFile] = useState(false);
    const dragCounter = useRef(0);

    // Refs to solve stale closure issues in global event listeners
    const layoutRef = useRef(layout);
    useEffect(() => { layoutRef.current = layout; }, [layout]);
    const draggedPanelRef = useRef(draggedPanel);
    useEffect(() => { draggedPanelRef.current = draggedPanel; }, [draggedPanel]);
    const dropTargetRef = useRef(dropTarget);
    useEffect(() => { dropTargetRef.current = dropTarget; }, [dropTarget]);

    const isDesktop = useMediaQuery('(min-width: 1024px)');
    
    const handleSettingsChange = useCallback((newSettings: AppSettings) => {
        setSettings(newSettings);
    }, []);

    const handleInitialImageUpload = useCallback(async (file: File) => {
        if (!validateImageFile(file)) return;
        setIsLoading(true);
        setLoaderMessage('Processing initial image...');
        const reader = new FileReader();
        reader.onloadend = async () => {
            const imageUrl = reader.result as string;
            const newNode: ImageNode = {
                id: crypto.randomUUID(),
                imageUrl,
                prompt: 'Initial Image',
                parentIds: [],
                generation: 0,
            };
            setNodes([newNode]);
            setSelectedNodeIds(new Set([newNode.id]));
            setIsLoading(false);
        };
        reader.onerror = () => {
            toast.error('We could not read that file. Please try again.');
            setIsLoading(false);
        };
        reader.readAsDataURL(file);
    }, []);
    
    const handleAddNewImage = useCallback(async (file: File) => {
        if (!validateImageFile(file)) return;
        setIsLoading(true);
        setLoaderMessage('Adding new root image...');
        const reader = new FileReader();
        reader.onloadend = async () => {
            const imageUrl = reader.result as string;
            const newNode: ImageNode = {
                id: crypto.randomUUID(),
                imageUrl,
                prompt: 'New Root Image',
                parentIds: [],
                generation: 0,
            };
            setNodes(prev => [...prev, newNode]);
            setSelectedNodeIds(new Set([newNode.id]));
            setIsLoading(false);
        };
        reader.onerror = () => {
            toast.error('We could not read that file. Please try again.');
            setIsLoading(false);
        };
        reader.readAsDataURL(file);
    }, []);

    const handleGenerate = useCallback(async (prompt: string, numVariations: number, useAIVariations: boolean, variationLevel: number, aspectRatio: string) => {
        const sourceNodes = nodes.filter(n => selectedNodeIds.has(n.id));
        if (sourceNodes.length === 0) return;

        const sourceImages = sourceNodes.map(n => dataUrlToBase64(n.imageUrl));
        const parentIds = sourceNodes.map(n => n.id);
        const generation = sourceNodes.length > 0 ? Math.max(...sourceNodes.map(n => n.generation)) + 1 : 1;

        // Use setIsLoading only for non-image generation tasks like prompt variation
        setIsLoading(true);

        try {
            let prompts: string[] = Array(numVariations).fill(prompt);
            
            if (useAIVariations && prompt) {
                setLoaderMessage('Generating prompt variations...');
                try {
                    const variations = await generatePromptVariations(prompt, numVariations, sourceImages, variationLevel, settings.prompter);
                    if (variations.length > 0) {
                        prompts = variations;
                    }
                } catch (e) {
                    console.error("Failed to generate prompt variations, falling back.", e);
                    toast.warn("AI prompt variation failed, using base prompt.");
                }
            }
            
            setIsLoading(false); // Turn off full-screen loader
            setSelectedNodeIds(new Set());

            // --- Skeleton Loader Logic ---
            const initialGhostNodes: GhostNode[] = prompts.map(() => ({
                id: crypto.randomUUID(),
                parentIds,
                generation,
            }));
            setGhostNodes(initialGhostNodes);
            setIsGenerating(true);
            
            let successfulGenerations = 0;
            const newNodeIds: string[] = [];

            const generationPromises = prompts.map((currentPrompt, index) => {
                const ghostId = initialGhostNodes[index].id;

                return generateImageVariations(currentPrompt, sourceImages, settings.imageGen.safetySettings, aspectRatio)
                    .then(generatedImages => {
                        if (generatedImages.length > 0) {
                            successfulGenerations++;
                            const imageUrl = generatedImages[0]; // Assuming one image per prompt for simplicity
                            const newId = crypto.randomUUID();
                            const newNode: ImageNode = {
                                id: newId,
                                imageUrl,
                                prompt: currentPrompt,
                                parentIds,
                                generation,
                            };
                            
                            // Replace ghost node with real node
                            setNodes(prev => [...prev, newNode]);
                            setGhostNodes(prev => prev.filter(g => g.id !== ghostId));
                            newNodeIds.push(newId);

                        } else {
                             // Remove ghost node on failure
                            setGhostNodes(prev => prev.filter(g => g.id !== ghostId));
                        }
                    })
                    .catch(e => {
                        console.error(`Failed to generate image for prompt: "${currentPrompt}"`, e);
                        toast.error(`Generation failed: ${e.message}`);
                         // Remove ghost node on error
                        setGhostNodes(prev => prev.filter(g => g.id !== ghostId));
                    });
            });
            
            await Promise.all(generationPromises);

            if (newNodeIds.length > 0) {
                setSelectedNodeIds(new Set(newNodeIds));
                setViewedNodeId(newNodeIds[0]);
            }

            if (successfulGenerations === 0 && prompts.length > 0) {
                toast.error("Image generation failed for all prompts. Please check safety settings or adjust your prompt.");
            } else if (successfulGenerations < prompts.length) {
                toast.warn(`${prompts.length - successfulGenerations} image generations failed, likely due to safety settings.`);
            }
        } catch (error: any) {
            console.error("An error occurred during the generation process:", error);
            toast.error(error.message || 'An unexpected error occurred during generation.');
            setIsLoading(false); // Ensure loader is off on error
            setGhostNodes([]); // Clear ghost nodes on major error
        } finally {
            setIsGenerating(false);
        }
    }, [nodes, selectedNodeIds, settings.prompter, settings.imageGen]);
    
    const handleNodeClick = useCallback((node: ImageNode, event: React.MouseEvent | MouseEvent) => {
        const isMultiSelect = isSelectMode || event.metaKey || event.ctrlKey;
        if (isMultiSelect) {
            setSelectedNodeIds(prev => {
                const newSet = new Set(prev);
                if (newSet.has(node.id)) {
                    newSet.delete(node.id);
                } else {
                    newSet.add(node.id);
                }
                return newSet;
            });
        } else {
             setSelectedNodeIds(new Set([node.id]));
        }
    }, [isSelectMode]);
    
    const handleNodeView = useCallback((node: ImageNode) => {
        setViewedNodeId(node.id);
        setSelectedNodeIds(new Set([node.id]));
    }, []);

    const handleOpenFullScreen = useCallback((node: ImageNode) => {
        setFullScreenNodeId(node.id);
    }, []);

    const handleCloseFullScreen = useCallback(() => {
        setFullScreenNodeId(null);
    }, []);


    const handleDeleteNode = useCallback((nodeIdToDelete: string) => {
        setNodes(prevNodes => {
            const nodesToDelete = new Set<string>();
            const queue: string[] = [nodeIdToDelete];
            nodesToDelete.add(nodeIdToDelete);

            while (queue.length > 0) {
                const currentId = queue.shift()!;
                const children = prevNodes.filter(n => n.parentIds.includes(currentId));
                children.forEach(child => {
                    if (!nodesToDelete.has(child.id)) {
                        nodesToDelete.add(child.id);
                        queue.push(child.id);
                    }
                });
            }

            setSelectedNodeIds(prevSelected => {
                const newSet = new Set(prevSelected);
                nodesToDelete.forEach(id => newSet.delete(id));
                return newSet;
            });

            if (viewedNodeId && nodesToDelete.has(viewedNodeId)) {
                setViewedNodeId(null);
            }
            if (historyNode && nodesToDelete.has(historyNode.id)) {
                setHistoryNode(null);
            }
            
            return prevNodes.filter(n => !nodesToDelete.has(n.id));
        });
    }, [viewedNodeId, historyNode]);
    
    const handleToggleSelection = useCallback((nodeId: string) => {
         setSelectedNodeIds(prev => {
            const newSet = new Set(prev);
            if (newSet.has(nodeId)) {
                newSet.delete(nodeId);
            } else {
                newSet.add(nodeId);
            }
            return newSet;
        });
    }, []);

    const handleShowHistory = useCallback((node: ImageNode) => {
        setHistoryNode(node);
    }, []);
    
    const handleRemoveSelectedNode = useCallback((nodeId: string) => {
        setSelectedNodeIds(prev => {
            const newSet = new Set(prev);
            newSet.delete(nodeId);
            return newSet;
        });
    }, []);

    const handleLayoutChange = useCallback((newLayout: Layout) => {
        setLayout(newLayout);
    }, []);

    const handlePanelContentChange = useCallback((panelId: string, newContent: PanelContent) => {
        setLayout(prevLayout => swapPanelContents(prevLayout, panelId, newContent));
    }, []);

    // Drag and Drop Handlers
    const handlePanelDragStart = useCallback((panelId: string, content: PanelContent, e: React.MouseEvent | React.TouchEvent) => {
        if ('touches' in e) {
            // Prevent scrolling while dragging a panel on touch devices
            e.preventDefault();
        }

        const isTouchEvent = 'touches' in e;
        const clientX = isTouchEvent ? e.touches[0].clientX : e.clientX;
        const clientY = isTouchEvent ? e.touches[0].clientY : e.clientY;

        const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
        dragStartOffset.current = {
            x: clientX - rect.left,
            y: clientY - rect.top,
        };
        setDraggedPanel({ id: panelId, content });
        setGhostPosition({
            x: clientX - dragStartOffset.current.x,
            y: clientY - dragStartOffset.current.y,
        });

        const handleMove = (moveClientX: number, moveClientY: number) => {
            setGhostPosition({
                x: moveClientX - dragStartOffset.current.x,
                y: moveClientY - dragStartOffset.current.y,
            });
        };

        const handleMouseMove = (moveEvent: MouseEvent) => handleMove(moveEvent.clientX, moveEvent.clientY);
        const handleTouchMove = (moveEvent: TouchEvent) => {
            if (moveEvent.touches.length > 0) {
                handleMove(moveEvent.touches[0].clientX, moveEvent.touches[0].clientY);
            }
        };
        
        const handleUp = () => {
            const currentDraggedPanel = draggedPanelRef.current;
            const currentDropTarget = dropTargetRef.current;
            const currentLayout = layoutRef.current;
    
            if (currentDraggedPanel && currentDropTarget) {
                let finalLayout: Layout | null = null;
                if (currentDropTarget.panelId === currentDraggedPanel.id) {
                    // Dropping on self, do nothing to layout
                } else if (currentDropTarget.position === 'center') {
                    finalLayout = swapPanelContents(currentLayout, currentDraggedPanel.id, currentDropTarget.panelId);
                } else {
                    const { newRoot, removedNode } = removeNodeFromLayout(currentLayout, currentDraggedPanel.id);
                    if (newRoot && removedNode) {
                        finalLayout = insertNodeIntoLayout(newRoot, removedNode, currentDropTarget.panelId, currentDropTarget.position);
                    }
                }
                if (finalLayout) {
                    setLayout(finalLayout);
                }
            }
    
            setDraggedPanel(null);
            setDropTarget(null);
            setGhostPosition(null);

            window.removeEventListener('mousemove', handleMouseMove);
            window.removeEventListener('mouseup', handleUp);
            window.removeEventListener('touchmove', handleTouchMove);
            window.removeEventListener('touchend', handleUp);
        };

        if (isTouchEvent) {
            window.addEventListener('touchmove', handleTouchMove, { passive: false });
            window.addEventListener('touchend', handleUp);
        } else {
            window.addEventListener('mousemove', handleMouseMove);
            window.addEventListener('mouseup', handleUp);
        }
    }, []);

    const handleMobileResizeStart = useCallback((e: React.MouseEvent | React.TouchEvent) => {
        e.preventDefault();

        const handleMove = (clientY: number) => {
            const totalHeight = window.innerHeight;
            if (totalHeight === 0) return;

            let newHeightPercent = (clientY / totalHeight) * 100;

            const minHeight = 20; // 20%
            const maxHeight = 80; // 80%
            newHeightPercent = Math.max(minHeight, Math.min(maxHeight, newHeightPercent));

            setMobileTopPanelHeight(newHeightPercent);
        };
        
        const handleMouseMove = (moveEvent: MouseEvent) => {
            handleMove(moveEvent.clientY);
        };

        const handleTouchMove = (moveEvent: TouchEvent) => {
            if (moveEvent.touches.length > 0) {
                handleMove(moveEvent.touches[0].clientY);
            }
        };

        const handleMouseUp = () => {
            window.removeEventListener('mousemove', handleMouseMove);
            window.removeEventListener('mouseup', handleMouseUp);
        };

        const handleTouchEnd = () => {
            window.removeEventListener('touchmove', handleTouchMove);
            window.removeEventListener('touchend', handleTouchEnd);
        };
        
        if ('touches' in e.nativeEvent) {
            window.addEventListener('touchmove', handleTouchMove);
            window.addEventListener('touchend', handleTouchEnd);
        } else {
            window.addEventListener('mousemove', handleMouseMove);
            window.addEventListener('mouseup', handleMouseUp);
        }
    }, []);

    // Global file drag & drop handlers
    const handleGlobalDragOver = useCallback((e: React.DragEvent) => {
        e.preventDefault();
    }, []);

    const handleGlobalDragEnter = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        dragCounter.current++;
        if (e.dataTransfer.items && e.dataTransfer.items.length > 0) {
            setIsDraggingFile(true);
        }
    }, []);

    const handleGlobalDragLeave = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        dragCounter.current--;
        if (dragCounter.current === 0) {
            setIsDraggingFile(false);
        }
    }, []);

    const handleGlobalDrop = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        setIsDraggingFile(false);
        dragCounter.current = 0;
        
        if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
            const file = e.dataTransfer.files[0];
            if (file.type.startsWith('image/')) {
                handleAddNewImage(file);
            } else {
                toast.error("Please drop an image file.");
            }
            e.dataTransfer.clearData();
        }
    }, [handleAddNewImage]);


    const historyPath = useMemo(() => {
        if (!historyNode) return [];
        const path: ImageNode[] = [];
        let currentNode: ImageNode | undefined = historyNode;
        const nodeMap = new Map(nodes.map(n => [n.id, n]));
        
        while (currentNode) {
            path.unshift(currentNode);
            const parentId = currentNode.parentIds[0];
            currentNode = parentId ? nodeMap.get(parentId) : undefined;
        }
        return path;
    }, [historyNode, nodes]);

    const selectedNodes = useMemo(() => {
        return nodes.filter(n => selectedNodeIds.has(n.id));
    }, [nodes, selectedNodeIds]);

    const viewedNode = useMemo(() => nodes.find(n => n.id === viewedNodeId), [nodes, viewedNodeId]);
    const fullScreenNode = useMemo(() => nodes.find(n => n.id === fullScreenNodeId), [nodes, fullScreenNodeId]);

    const carouselNodes = useMemo(() => {
        const activeNode = fullScreenNode || viewedNode;
        if (!activeNode) return [];
        const nodeMap = new Map(nodes.map(n => [n.id, n]));

        const parents = activeNode.parentIds.map(pid => nodeMap.get(pid)).filter((n): n is ImageNode => !!n);
        const siblings = nodes.filter(n =>
            n.id !== activeNode.id &&
            activeNode.parentIds.length > 0 &&
            n.parentIds.length === activeNode.parentIds.length &&
            n.parentIds.every(pid => activeNode.parentIds.includes(pid))
        );
        const children = nodes.filter(n => n.parentIds.includes(activeNode.id));

        const sortedSiblings = siblings.sort((a, b) => a.id.localeCompare(b.id));
        const sortedChildren = children.sort((a, b) => a.id.localeCompare(b.id));
        
        const finalNodes: ImageNode[] = [];
        const addedIds = new Set<string>();
        const addNode = (node: ImageNode) => {
            if (!addedIds.has(node.id)) {
                finalNodes.push(node);
                addedIds.add(node.id);
            }
        };

        parents.forEach(addNode);
        addNode(activeNode);
        sortedSiblings.forEach(addNode);
        sortedChildren.forEach(addNode);

        return finalNodes;
    }, [viewedNode, fullScreenNode, nodes]);

    const renderPanelContent = useCallback((panelLayout: Layout) => {
         if (panelLayout.type !== 'panel') return null;
         const { content, id } = panelLayout;

        const panelComponent = () => {
            switch (content) {
                case 'tree':
                    return (
                        <ErrorBoundary name="ImageTree">
                            <ImageTree 
                                nodes={nodes}
                                ghostNodes={ghostNodes}
                                selectedNodeIds={selectedNodeIds}
                                onNodeClick={handleNodeClick}
                                onNodeView={handleNodeView}
                                isSelectMode={isSelectMode}
                                setIsSelectMode={setIsSelectMode}
                                onDeleteNode={(node) => handleDeleteNode(node.id)}
                            />
                        </ErrorBoundary>
                    );
                case 'controls':
                    return <ControlPanel 
                                onGenerate={handleGenerate}
                                onInitialImageUpload={handleInitialImageUpload}
                                onAddNewImage={handleAddNewImage}
                                hasImage={nodes.length > 0}
                                selectedNodes={selectedNodes}
                                onRemoveSelectedNode={handleRemoveSelectedNode}
                                onViewNode={handleNodeView}
                                isSelectMode={isSelectMode}
                                setIsSelectMode={setIsSelectMode}
                                onOpenSettings={() => setIsSettingsOpen(true)}
                                isGenerating={isGenerating}
                            />;
                case 'viewer':
                    return <ImageViewer
                                node={viewedNode}
                                isModal={false}
                                isSelected={viewedNode ? selectedNodeIds.has(viewedNode.id) : false}
                                onToggleSelect={() => viewedNode && handleToggleSelection(viewedNode.id)}
                                onClose={() => {}}
                                onShowHistory={handleShowHistory}
                                onDelete={(node) => handleDeleteNode(node.id)}
                                onOpenFullScreen={handleOpenFullScreen}
                                carouselNodes={carouselNodes}
                                onNavigate={(node) => setViewedNodeId(node.id)}
                            />;
                default:
                    return null;
            }
        };

        return (
            <Panel 
                id={id}
                content={content} 
                availableContents={availablePanelContents}
                onContentChange={(newContent) => handlePanelContentChange(id, newContent)}
                onPanelDragStart={handlePanelDragStart}
                setDropTarget={setDropTarget}
                draggedPanel={draggedPanel}
                dropTarget={dropTarget}
            >
                {panelComponent()}
            </Panel>
        );
    }, [
        nodes, ghostNodes, selectedNodeIds, isSelectMode, handleNodeClick, handleNodeView, handleDeleteNode, 
        handleGenerate, handleInitialImageUpload, handleAddNewImage, selectedNodes, handleRemoveSelectedNode,
        setIsSelectMode, handleShowHistory, viewedNode, carouselNodes, handleToggleSelection,
        handlePanelContentChange, handlePanelDragStart, draggedPanel, dropTarget, handleOpenFullScreen
    ]);


    return (
        <main 
            className="h-full w-full bg-gray-900 text-white flex flex-col overflow-hidden"
            onDragEnter={handleGlobalDragEnter}
            onDragLeave={handleGlobalDragLeave}
            onDragOver={handleGlobalDragOver}
            onDrop={handleGlobalDrop}
        >
            <ToastContainer theme="dark" position="bottom-right" />
            {isLoading && <Loader message={loaderMessage} />}
            {historyNode && <HistoryViewer path={historyPath} onClose={() => setHistoryNode(null)} />}
            {fullScreenNode && (
                <FullScreenImageViewer
                    node={fullScreenNode}
                    onClose={handleCloseFullScreen}
                    isSelected={selectedNodeIds.has(fullScreenNode.id)}
                    onToggleSelect={() => handleToggleSelection(fullScreenNode.id)}
                    onShowHistory={handleShowHistory}
                    onDelete={(node) => {
                        handleDeleteNode(node.id);
                        handleCloseFullScreen();
                    }}
                    carouselNodes={carouselNodes}
                    onNavigate={(node) => setFullScreenNodeId(node.id)}
                />
            )}
            <SettingsModal 
                isOpen={isSettingsOpen}
                onClose={() => setIsSettingsOpen(false)}
                settings={settings}
                onSettingsChange={handleSettingsChange}
            />
             {draggedPanel && ghostPosition && (
                <DragGhost content={draggedPanel.content} position={ghostPosition} />
            )}
            {isDraggingFile && nodes.length > 0 && <DropZoneOverlay />}


            {isDesktop ? (
                 <div className="flex-1 p-2 w-full h-full">
                    <DockingLayout 
                        layout={layout}
                        onLayoutChange={handleLayoutChange}
                        renderPanel={renderPanelContent}
                    />
                </div>
            ) : (
                <div className="flex flex-col flex-1 w-full h-full">
                    <div style={{ height: `${mobileTopPanelHeight}%` }} className="min-h-0">
                       {viewedNode ? (
                            <ImageViewer
                                node={viewedNode}
                                isModal={false}
                                showCloseButton={true}
                                isSelected={selectedNodeIds.has(viewedNode.id)}
                                onToggleSelect={() => handleToggleSelection(viewedNode.id)}
                                onClose={() => setViewedNodeId(null)}
                                onShowHistory={handleShowHistory}
                                onOpenFullScreen={handleOpenFullScreen}
                                onDelete={(node) => handleDeleteNode(node.id)}
                                carouselNodes={carouselNodes}
                                onNavigate={(node) => setViewedNodeId(node.id)}
                            />
                       ) : (
                            <ErrorBoundary name="ImageTree">
                            <ImageTree 
                                nodes={nodes}
                                ghostNodes={ghostNodes}
                                selectedNodeIds={selectedNodeIds}
                                onNodeClick={handleNodeClick}
                                onNodeView={handleNodeView}
                                isSelectMode={isSelectMode}
                                setIsSelectMode={setIsSelectMode}
                                onDeleteNode={(node) => handleDeleteNode(node.id)}
                            />
                            </ErrorBoundary>
                       )}
                    </div>
                    <div
                        onMouseDown={handleMobileResizeStart}
                        onTouchStart={handleMobileResizeStart}
                        className="h-5 bg-gray-700 cursor-row-resize hover:bg-teal-500 active:bg-teal-600 transition-colors flex-shrink-0 flex items-center justify-center"
                        aria-label="Resize panels"
                        role="separator"
                    >
                        <div className="w-8 h-1 bg-gray-500 rounded-full" />
                    </div>
                    <div className="flex-1 min-h-0 relative">
                        <ControlPanel 
                            onGenerate={handleGenerate}
                            onInitialImageUpload={handleInitialImageUpload}
                            onAddNewImage={handleAddNewImage}
                            hasImage={nodes.length > 0}
                            selectedNodes={selectedNodes}
                            onRemoveSelectedNode={handleRemoveSelectedNode}
                            onViewNode={handleNodeView}
                            isSelectMode={isSelectMode}
                            setIsSelectMode={setIsSelectMode}
                            onOpenSettings={() => setIsSettingsOpen(true)}
                            isGenerating={isGenerating}
                        />
                    </div>
                </div>
            )}
        </main>
    );
}

export default App;

================
File: index.html
================
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Gemini Image Weaver</title>
    <script src="https://cdn.tailwindcss.com"></script>
  <script type="importmap">
{
  "imports": {
    "react/": "https://aistudiocdn.com/react@^19.1.1/",
    "react": "https://aistudiocdn.com/react@^19.1.1",
    "react-dom/": "https://aistudiocdn.com/react-dom@^19.1.1/",
    "@google/genai": "https://aistudiocdn.com/@google/genai@^1.19.0",
    "react-toastify/": "https://aistudiocdn.com/react-toastify@^11.0.5/",
    "react-toastify": "https://aistudiocdn.com/react-toastify@^11.0.5",
    "uuid": "https://aistudiocdn.com/uuid@^13.0.0",
    "d3": "https://aistudiocdn.com/d3@^7.9.0",
    "framer-motion": "https://aistudiocdn.com/framer-motion@^11.2.12"
  }
}
</script>
<style>
  html, body, #root {
    height: 100%;
    margin: 0;
    padding: 0;
    overflow: hidden;
  }
  
  /* --- Animations --- */
  @keyframes glowing-enhance {
    0% {
      box-shadow: 0 0 2px rgba(234, 179, 8, 0.4);
      border-color: rgba(234, 179, 8, 0.5);
    }
    50% {
      box-shadow: 0 0 8px rgba(234, 179, 8, 0.7), 0 0 12px rgba(234, 179, 8, 0.5);
      border-color: rgba(234, 179, 8, 1);
    }
    100% {
      box-shadow: 0 0 2px rgba(234, 179, 8, 0.4);
      border-color: rgba(234, 179, 8, 0.5);
    }
  }

  @keyframes icon-spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
  
  @keyframes pulse-ghost {
    0%, 100% {
      opacity: 0.7;
      border-color: rgba(99, 179, 237, 0.5);
    }
    50% {
      opacity: 1;
      border-color: rgba(99, 179, 237, 1);
    }
  }

  /* --- Utility Classes --- */
  .prompt-enhancing {
    animation: glowing-enhance 1.8s infinite ease-in-out;
  }

  .btn-press-feedback {
    transition: box-shadow 0.18s ease, filter 0.18s ease;
  }
  .btn-press-feedback:focus-visible {
    outline: none;
    box-shadow: 0 0 0 3px rgba(94, 234, 212, 0.55);
  }
  .btn-press-feedback:active {
    filter: brightness(1.08);
    box-shadow: 0 0 12px rgba(94, 234, 212, 0.45);
  }

  @keyframes node-appear {
    from {
      opacity: 0;
      transform: scale(0.85);
    }
    to {
      opacity: 1;
      transform: scale(1);
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .graph-node {
      animation: none !important;
    }
  }

  .generate-spinner {
    width: 1rem;
    height: 1rem;
    border-radius: 9999px;
    border: 2px solid rgba(255,255,255,0.35);
    border-top-color: rgba(255,255,255,0.95);
    animation: icon-spin 0.75s linear infinite;
  }

  .generate-busy {
    position: relative;
    z-index: 0;
  }

  .generate-busy::after {
    content: '';
    position: absolute;
    inset: -2px;
    border-radius: inherit;
    background: linear-gradient(90deg, rgba(45,212,191,0.35), rgba(129,140,248,0.35), rgba(45,212,191,0.35));
    filter: blur(12px);
    opacity: 0.7;
    z-index: -1;
    animation: shimmer 1.2s ease-in-out infinite;
  }

  .generate-busy:disabled {
    cursor: progress !important;
  }

  @keyframes shimmer {
    0% { transform: translateX(-10%); }
    50% { transform: translateX(10%); }
    100% { transform: translateX(-10%); }
  }

  .icon-thinking {
    animation: icon-spin 1s linear infinite;
  }
  
  .ghost-node-pulse {
    animation: pulse-ghost 2s infinite ease-in-out;
    border-style: dashed !important;
  }

  .drop-zone-active {
    border-color: #2dd4bf !important; /* teal-400 */
    background-color: rgba(45, 212, 191, 0.1);
    transform: scale(1.02);
    transition: transform 0.2s ease-out, border-color 0.2s, background-color 0.2s;
  }
  
  .node:not(.ghost-node-pulse) {
    transition: box-shadow 0.2s ease-out;
  }
  .node:not(.ghost-node-pulse):hover {
    box-shadow: 0 0 15px rgba(99, 179, 237, 0.8) !important;
    z-index: 10;
  }

  /* --- Prompt Diff Viewer --- */
  .prompt-diff-viewer {
    white-space: pre-wrap;
    word-wrap: break-word;
    font-size: 0.875rem;
    line-height: 1.5;
    color: #d1d5db; /* gray-300 */
    -webkit-user-select: none; /* Safari */
    -ms-user-select: none; /* IE 10+ */
    user-select: none;
    pointer-events: none;
  }
  .prompt-diff-viewer ins {
    background-color: rgba(16, 185, 129, 0.2); /* Emerald-500 with opacity */
    text-decoration: none;
    border-radius: 0.25rem;
    padding: 0.1rem 0;
  }
  .prompt-diff-viewer del {
    color: rgba(239, 68, 68, 0.7); /* Red-500 with opacity */
    text-decoration: line-through;
  }

</style>
<link rel="stylesheet" href="/index.css">
</head>
  <body class="bg-gray-900 text-white">
    <div id="root"></div>
    <script type="module" src="/index.tsx"></script>
  </body>
</html>

================
File: index.tsx
================
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const rootElement = document.getElementById('root');
if (!rootElement) {
  throw new Error("Could not find root element to mount to");
}

const root = ReactDOM.createRoot(rootElement);
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

================
File: metadata.json
================
{
  "name": "Gemini Image Weaver",
  "description": "An intuitive UI for rapid image iteration using Gemini. Generate creative variations, combine images, and explore your ideas in a dynamic visual tree.",
  "requestFramePermissions": []
}

================
File: package.json
================
{
  "name": "gemini-image-weaver",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "dev:lan": "VITE_HOST=public vite --host 0.0.0.0",
    "dev:ts": "bash scripts/dev-tailscale.sh",
    "build": "vite build",
    "preview": "vite preview",
    "preview:ts": "VITE_HOST=public vite preview --host 0.0.0.0"
  },
  "dependencies": {
    "react": "^19.1.1",
    "react-dom": "^19.1.1",
    "@google/genai": "^1.19.0",
    "react-toastify": "^11.0.5",
    "uuid": "^13.0.0",
    "d3": "^7.9.0",
    "framer-motion": "^11.2.12"
  },
  "devDependencies": {
    "@types/node": "^22.14.0",
    "typescript": "~5.8.2",
    "vite": "^6.2.0"
  }
}

================
File: README.md
================
<div align="center">
<img width="1200" height="475" alt="GHBanner" src="https://github.com/user-attachments/assets/0aa67016-6eaf-458a-adb2-6e31a0763ed6" />
</div>

# Run and deploy your AI Studio app

This contains everything you need to run your app locally.

View your app in AI Studio: https://ai.studio/apps/drive/1JZjRhLpjzcgyADW--rzgWV4kG4KPedEe

## Run Locally

**Prerequisites:**  Node.js


1. Install dependencies:
   `npm install`
2. Create or edit [.env.local](.env.local) and set:
   - `VITE_GEMINI_API_KEY=YOUR_KEY_HERE`
   (The dev server must be restarted after changing env files.)
3. Run the app:
   `npm run dev`

## Remote access over Tailscale (or LAN)

If you want teammates on your tailnet to use your dev server from their devices:

- Quick LAN/Tailscale run: `npm run dev:lan` (binds to 0.0.0.0)
- Recommended for Tailscale: `npm run dev:ts`

`npm run dev:ts` will:
- Bind the Vite dev server to `0.0.0.0` so it’s reachable via your Tailscale IP.
- Attempt to detect your Tailscale IPv4 and set it for HMR so hot‑reload works remotely.

Connect from another device using your Tailscale IP and port, e.g. `http://100.x.x.x:5173`.

Preview build (also network‑bound):
- Local: `npm run preview`
- Tailscale/LAN: `npm run preview:ts`

Environment toggles (optional):
- `VITE_HOST=public` ⇒ binds dev/preview to `0.0.0.0`.
- `VITE_PORT` ⇒ dev server port (default 5173).
- `VITE_HMR_HOST` and `VITE_HMR_PORT` ⇒ override HMR host/port if needed.

================
File: tsconfig.json
================
{
  "compilerOptions": {
    "target": "ES2022",
    "experimentalDecorators": true,
    "useDefineForClassFields": false,
    "module": "ESNext",
    "lib": [
      "ES2022",
      "DOM",
      "DOM.Iterable"
    ],
    "skipLibCheck": true,
    "types": [
      "node"
    ],
    "moduleResolution": "bundler",
    "isolatedModules": true,
    "moduleDetection": "force",
    "allowJs": true,
    "jsx": "react-jsx",
    "paths": {
      "@/*": [
        "./*"
      ]
    },
    "allowImportingTsExtensions": true,
    "noEmit": true
  }
}

================
File: types.ts
================
export interface ImageNode {
    id: string;
    imageUrl: string;
    prompt: string;
    parentIds: string[];
    generation: number;
}

// Represents a placeholder for an image that is currently being generated.
export interface GhostNode {
    id: string;
    parentIds: string[];
    generation: number;
}


export type HarmCategory =
  | 'HARM_CATEGORY_HARASSMENT'
  | 'HARM_CATEGORY_HATE_SPEECH'
  | 'HARM_CATEGORY_SEXUALLY_EXPLICIT'
  | 'HARM_CATEGORY_DANGEROUS_CONTENT';

export type HarmBlockThreshold =
  | 'BLOCK_NONE'
  | 'BLOCK_ONLY_HIGH'
  | 'BLOCK_MEDIUM_AND_ABOVE'
  | 'BLOCK_LOW_AND_ABOVE';

export interface ImageGenSettings {
    safetySettings: { category: HarmCategory; threshold: HarmBlockThreshold }[];
}

export interface PrompterSettings {
    // general
    safety: string; // Placeholder for now
    outputLength: 'short' | 'medium' | 'long';
    useTokenLimit: boolean;
    maxTokens: number;
    customInstructions: string;
    // advanced
    temperature: number;
    topK: number;
    topP: number;
}

export interface AppSettings {
    prompter: PrompterSettings;
    imageGen: ImageGenSettings;
}

// New types for Docking Layout
export type PanelContent = 'tree' | 'controls' | 'viewer';

export interface Panel {
    id: string;
    type: 'panel';
    content: PanelContent;
}

export interface SplitContainer {
    id:string;
    type: 'split';
    direction: 'horizontal' | 'vertical';
    children: [Layout, Layout];
    sizes: [number, number]; // Percentages
}

export type Layout = Panel | SplitContainer;

// Types for Drag-and-Drop
export type DropPosition = 'top' | 'bottom' | 'left' | 'right' | 'center';

export interface DropTarget {
    panelId: string;
    position: DropPosition;
}

================
File: vite.config.ts
================
import path from 'path';
import { defineConfig, loadEnv } from 'vite';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, '.', '');

  // Bind address: set VITE_HOST=public (or 0.0.0.0) to expose on LAN/Tailscale.
  const bindAll = (env.VITE_HOST || '').toLowerCase() === 'public' || env.VITE_HOST === '0.0.0.0' || env.VITE_HOST === 'true';
  const host = bindAll ? true : (env.VITE_HOST || '127.0.0.1');

  const port = Number(env.VITE_PORT || 5173);

  // Optional HMR host override for remote clients (e.g., Tailscale IP)
  const hmrHost = env.VITE_HMR_HOST || undefined;
  const hmrPort = Number(env.VITE_HMR_PORT || port);

  return {
    define: {
      'process.env.API_KEY': JSON.stringify(env.GEMINI_API_KEY),
      'process.env.GEMINI_API_KEY': JSON.stringify(env.GEMINI_API_KEY)
    },
    resolve: {
      alias: {
        '@': path.resolve(__dirname, '.'),
      }
    },
    server: {
      host,
      port,
      hmr: hmrHost ? { host: hmrHost, port: hmrPort } : undefined,
    },
    preview: {
      host,
      port: Number(env.VITE_PREVIEW_PORT || 4173),
    }
  };
});



================================================================
End of Codebase
================================================================
