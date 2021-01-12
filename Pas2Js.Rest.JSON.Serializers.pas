unit Pas2Js.Rest.JSON.Serializers;

interface

uses Rtti, JS, TypInfo, Delphi.Rest.JSON.Serializer.Intf;

type
  TRestJsonSerializer = class(TInterfacedObject, IRestJsonSerializer)
  private
    function Deserialize(const AJson: String; TypeInfo: PTypeInfo): TValue;
    function Serialize(const AValue: TValue): String;
  protected
    function CreateObject(RttiType: TRttiType): TObject; virtual;
    function DeserializeArray(const JSON: JSValue; RttiType: TRttiType): TValue; virtual;
    function DeserializeJSON(const JSON: JSValue; RttiType: TRttiType): TValue; virtual;
    function DeserializeObject(const JSON: JSValue; RttiType: TRttiType): TValue; virtual;
    function SerializeJSON(Key, Value: JSValue): JSValue; virtual;
  end;

implementation

uses SysUtils;

{ TRestJsonSerializer }

function TRestJsonSerializer.CreateObject(RttiType: TRttiType): TObject;
var
  Method: TRttiMethod;

begin
  for Method in RttiType.GetMethods do
    if (Method.MethodKind = mkConstructor) and (Length(Method.MethodTypeInfo.ProcSig.Params) = 0) then
      Exit(Method.Invoke(TJSObject(TRttiInstanceType(RttiType).MetaClassType), nil).AsObject);

  Result := TObject(TJSObject.Create(TJSObject(TRttiInstanceType(RttiType).MetaClassType)));
end;

function TRestJsonSerializer.Deserialize(const AJson: String; TypeInfo: PTypeInfo): TValue;
var
  Context: TRTTIContext;

  RttiType: TRttiType;

begin
  Context := TRTTIContext.Create;
  RttiType := Context.GetType(TypeInfo);

  Result := DeserializeJSON(TJSJSON.Parse(AJson), RttiType);

  Context.Free;
end;

function TRestJsonSerializer.DeserializeArray(const JSON: JSValue; RttiType: TRttiType): TValue;
var
  RttiArrayType: TRttiDynamicArrayType absolute RttiType;

  Value: JSValue;

  ValueArray: TJSArray absolute JSON;

  Return: TJSArray;

begin
  Return := TJSArray.new;

  for Value in ValueArray do
    Return.Push(DeserializeJSON(Value, RttiArrayType.ElementType).AsJSValue);

  Result := TValue.FromJSValue(Return);
end;

function TRestJsonSerializer.DeserializeJSON(const JSON: JSValue; RttiType: TRttiType): TValue;
begin
  if RttiType.IsInstance  then
    Result := DeserializeObject(JSON, RttiType)
  else if RttiType is TRttiDynamicArrayType then
    Result := DeserializeArray(JSON, RttiType)
  else
    Result := TValue.FromJSValue(JSON);
end;

function TRestJsonSerializer.DeserializeObject(const JSON: JSValue; RttiType: TRttiType): TValue;
var
  JSONObject: TJSObject absolute JSON;

  Key: String;

  Prop: TRttiProperty;

begin
  if JSON = NULL then
    Result := TValue.Empty
  else
  begin
    Result := TValue.FromJSValue(CreateObject(RttiType));

    for Key in TJSObject.Keys(JSONObject) do
    begin
      Prop := RttiType.GetProperty(Key);

      Prop.SetValue(Result.AsObject, DeserializeJSON(JSONObject[Key], Prop.PropertyType).AsJSValue);
    end;
  end;
end;

function TRestJsonSerializer.Serialize(const AValue: TValue): String;
begin
  Result := TJSJSON.stringify(AValue.AsJSValue, @SerializeJSON);
end;

function TRestJsonSerializer.SerializeJSON(Key, Value: JSValue): JSValue;
var
  CurrentObject: TJSObject absolute Value;

  NewObject: TJSObject;

  FieldName: String;

begin
  if IsObject(Value) and not IsArray(Value) then
  begin
    NewObject := TJSObject.New;

    for FieldName in TJSObject.Keys(CurrentObject) do
      NewObject[FieldName.SubString(1)] := CurrentObject[FieldName];

    Result := NewObject;
  end
  else
    Result := Value;
end;

end.
