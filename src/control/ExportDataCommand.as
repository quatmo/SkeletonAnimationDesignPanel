package control
{
	import com.adobe.serialization.json.JSON;
	
	import dragonBones.objects.DataParser;
	import dragonBones.utils.ConstValues;
	
	import flash.display.BitmapData;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.geom.Matrix;
	import flash.net.FileReference;
	import flash.utils.ByteArray;
	
	import message.Message;
	import message.MessageDispatcher;
	
	import model.ImportDataProxy;
	import model.JSFLProxy;
	import model.XMLDataProxy;
	
	import utils.BitmapDataUtil;
	import utils.GlobalConstValues;
	import utils.PNGEncoder;
	import utils.xmlToObject;
	
	import zero.zip.Zip;
	
	public class ExportDataCommand
	{
		public static const instance:ExportDataCommand = new ExportDataCommand();
		
		private var _fileREF:FileReference;
		private var _exportType:uint;
		private var _isExporting:Boolean;
		private var _exportScale:Number;
		
		private var _importDataProxy:ImportDataProxy;
		
		private var _xmlDataProxy:XMLDataProxy;
		private var _bitmapData:BitmapData;
		
		public function ExportDataCommand()
		{
			_fileREF = new FileReference();
			
			_importDataProxy = ImportDataProxy.getInstance();
		}
		
		public function export(exportType:uint, exportScale:Number):void
		{
			if(_isExporting)
			{
				return;
			}
			_isExporting = true;
			
			_exportType = exportType;
			_exportScale = exportScale;
			
			switch(_exportType)
			{
				case 0:
				case 2:
				case 5:
					_exportScale = 1;
					break;
			}
			
			exportStart();
		}
		
		private function exportStart():void
		{
			var dataBytes:ByteArray;
			var zip:Zip;
			var date:Date;
			
			_xmlDataProxy = _importDataProxy.xmlDataProxy;
			_bitmapData = _importDataProxy.textureAtlas.bitmapData;
			
			if(_exportScale != 1)
			{
				_xmlDataProxy = _xmlDataProxy.clone();
				var subBitmapDataDic:Object;
				var movieClip:MovieClip = _importDataProxy.textureAtlas.movieClip;
				if(movieClip && movieClip.totalFrames >= 3)
				{
					subBitmapDataDic = {};
					for each (var displayName:String in _xmlDataProxy.getDisplayList())
					{
						movieClip.gotoAndStop(movieClip.totalFrames);
						movieClip.gotoAndStop(displayName);
						subBitmapDataDic[displayName] = movieClip.getChildAt(0);
					}
				}
				else
				{
					subBitmapDataDic = BitmapDataUtil.getSubBitmapDataDic(
						_bitmapData,
						_xmlDataProxy.getSubTextureRectDic()
					);
				}
				
				_xmlDataProxy.scaleData(_exportScale);
					
				_bitmapData = BitmapDataUtil.getMergeBitmapData(
					subBitmapDataDic,
					_xmlDataProxy.getSubTextureRectDic(),
					_xmlDataProxy.textureAtlasWidth,
					_xmlDataProxy.textureAtlasHeight,
					_exportScale
				);
			}
			
			var isSWF:Boolean = _exportType == 0 || _exportType == 2 || _exportType == 5;
			var isXML:Boolean = _exportType == 2 || _exportType == 3 || _exportType == 4;
			
			switch(_exportType)
			{
				case 0:
					try
					{
						dataBytes = getSWFBytes();
						if(dataBytes)
						{
							exportSave(
								DataParser.compressData(
									xmlToObject(_xmlDataProxy.xml, GlobalConstValues.XML_LIST_NAMES), 
									xmlToObject(_xmlDataProxy.textureAtlasXML, GlobalConstValues.XML_LIST_NAMES), 
									dataBytes
								), 
								_importDataProxy.data.name + GlobalConstValues.SWF_SUFFIX
							);
							return;
						}
						break;
					}
					catch(_e:Error)
					{
						break;
					}
				case 1:
					try
					{
						dataBytes = getPNGBytes();
						if(dataBytes)
						{
							exportSave(
								DataParser.compressData(
									xmlToObject(_xmlDataProxy.xml, GlobalConstValues.XML_LIST_NAMES), 
									xmlToObject(_xmlDataProxy.textureAtlasXML, GlobalConstValues.XML_LIST_NAMES), 
									dataBytes
								), 
								_importDataProxy.data.name + GlobalConstValues.PNG_SUFFIX
							);
							return;
						}
						break;
					}
					catch(_e:Error)
					{
						break;
					}
				case 2:
				case 3:
				case 5:
				case 6:
					try
					{
						if(isSWF)
						{
							dataBytes = getSWFBytes();
						}
						else
						{
							dataBytes = getPNGBytes();
						}
						
						if(dataBytes)
						{
							date = new Date();
							zip = new Zip();
							zip.add(
								dataBytes, 
								GlobalConstValues.TEXTURE_NAME + (isSWF?GlobalConstValues.SWF_SUFFIX:GlobalConstValues.PNG_SUFFIX),
								date
							);
							if(isXML)
							{
								zip.add(
									_xmlDataProxy.xml.toXMLString(),
									GlobalConstValues.DRAGON_BONES_DATA_NAME + GlobalConstValues.XML_SUFFIX, 
									date
								);
								zip.add(
									_xmlDataProxy.textureAtlasXML.toXMLString(),
									GlobalConstValues.TEXTURE_ATLAS_DATA_NAME + GlobalConstValues.XML_SUFFIX, 
									date
								);
							}
							else
							{
								zip.add(
									com.adobe.serialization.json.JSON.encode(xmlToObject(_xmlDataProxy.xml, GlobalConstValues.XML_LIST_NAMES)), 
									GlobalConstValues.DRAGON_BONES_DATA_NAME + GlobalConstValues.JSON_SUFFIX, 
									date
								);
								zip.add(
									com.adobe.serialization.json.JSON.encode(xmlToObject(_xmlDataProxy.textureAtlasXML, GlobalConstValues.XML_LIST_NAMES)), 
									GlobalConstValues.TEXTURE_ATLAS_DATA_NAME + GlobalConstValues.JSON_SUFFIX, 
									date
								);
							}
							exportSave(
								zip.encode(), 
								_importDataProxy.data.name + GlobalConstValues.ZIP_SUFFIX
							);
							zip.clear();
							return;
						}
						break;
					}
					catch(_e:Error)
					{
						break;
					}
				case 4:
				case 7:
					try
					{
						date = new Date();
						zip = new Zip();
						
						if(_xmlDataProxy == _importDataProxy.xmlDataProxy)
						{
							_xmlDataProxy = _xmlDataProxy.clone();
						}
						_xmlDataProxy.changePath();
						
						
						subBitmapDataDic = BitmapDataUtil.getSubBitmapDataDic(
							_bitmapData, 
							_xmlDataProxy.getSubTextureRectDic()
						);
						for(var subTextureName:String in subBitmapDataDic)
						{
							var subBitmapData:BitmapData = subBitmapDataDic[subTextureName];
							zip.add(
								PNGEncoder.encode(subBitmapData), 
								GlobalConstValues.TEXTURE_NAME + "/" + subTextureName + GlobalConstValues.PNG_SUFFIX, 
								date
							);
							subBitmapData.dispose();
						}
						if(isXML)
						{
							zip.add(
								_xmlDataProxy.xml.toXMLString(), 
								GlobalConstValues.DRAGON_BONES_DATA_NAME + GlobalConstValues.XML_SUFFIX, 
								date
							);
							zip.add(
								_xmlDataProxy.textureAtlasXML.toXMLString(), 
								GlobalConstValues.TEXTURE_ATLAS_DATA_NAME + GlobalConstValues.XML_SUFFIX, 
								date
							);
						}
						else
						{
							zip.add(
								com.adobe.serialization.json.JSON.encode(xmlToObject(_xmlDataProxy.xml, GlobalConstValues.XML_LIST_NAMES)), 
								GlobalConstValues.DRAGON_BONES_DATA_NAME + GlobalConstValues.JSON_SUFFIX, 
								date
							);
							zip.add(
								com.adobe.serialization.json.JSON.encode(xmlToObject(_xmlDataProxy.textureAtlasXML, GlobalConstValues.XML_LIST_NAMES)), 
								GlobalConstValues.TEXTURE_ATLAS_DATA_NAME + GlobalConstValues.JSON_SUFFIX, 
								date
							);
						}
						
						exportSave(
							zip.encode(), 
							_importDataProxy.data.name + GlobalConstValues.ZIP_SUFFIX
						);
						zip.clear();
						return;
					}
					catch(_e:Error)
					{
						break;
					}
				default:
					break;
			}
			_isExporting = false;
			MessageDispatcher.dispatchEvent(MessageDispatcher.EXPORT_ERROR);
		}
		
		private function getSWFBytes():ByteArray
		{
			if(_importDataProxy.textureAtlas.movieClip)
			{
				return _importDataProxy.textureBytes;
			}
			return null;
		}
		
		private function getPNGBytes():ByteArray
		{
			if(_importDataProxy.textureAtlas.movieClip)
			{
				return PNGEncoder.encode(_bitmapData);
			}
			else
			{
				if(_bitmapData && _bitmapData != _importDataProxy.textureAtlas.bitmapData)
				{
					return PNGEncoder.encode(_bitmapData);
				}
				return _importDataProxy.textureBytes;
			}
			return null;
		}
		
		private function exportSave(fileData:ByteArray, fileName:String):void
		{
			MessageDispatcher.dispatchEvent(MessageDispatcher.EXPORT, fileName);
			_fileREF.addEventListener(Event.CANCEL, onFileSaveHandler);
			_fileREF.addEventListener(Event.COMPLETE, onFileSaveHandler);
			_fileREF.addEventListener(IOErrorEvent.IO_ERROR, onFileSaveHandler);
			_fileREF.save(fileData, fileName);
		}
		
		private function onFileSaveHandler(e:Event):void
		{
			_fileREF.removeEventListener(Event.CANCEL, onFileSaveHandler);
			_fileREF.removeEventListener(Event.COMPLETE, onFileSaveHandler);
			_fileREF.removeEventListener(IOErrorEvent.IO_ERROR, onFileSaveHandler);
			_isExporting = false;
			switch(e.type)
			{
				case Event.CANCEL:
					MessageDispatcher.dispatchEvent(MessageDispatcher.EXPORT_CANCEL);
					break;
				case IOErrorEvent.IO_ERROR:
					MessageDispatcher.dispatchEvent(MessageDispatcher.EXPORT_ERROR);
					break;
				case Event.COMPLETE:
					if(_bitmapData && _bitmapData != _importDataProxy.textureAtlas.bitmapData)
					{
						_bitmapData.dispose();
						_bitmapData = null;
					}
					MessageDispatcher.dispatchEvent(MessageDispatcher.EXPORT_COMPLETE);
					break;
			}
		}
	}
}