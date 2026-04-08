import { LightningElement, track } from "lwc";
import getAllObjects from "@salesforce/apex/FieldMappingController.getAllObjects";
import getObjectFields from "@salesforce/apex/FieldMappingController.getObjectFields";
import getRelatedObjects from "@salesforce/apex/FieldMappingController.getRelatedObjects";
import saveMappingConfig from "@salesforce/apex/FieldMappingController.saveMappingConfig";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class FieldMapperAdvanced extends LightningElement {
  @track objectOptions = [];
  @track selectedObject;
  @track allFields = [];
  @track mappedFields = [];
  @track generatedJSON;

  @track relatedData = [];
  @track isRelatedOpen = false;

  searchKey = "";

  isStandardOpen = true;
  isCustomOpen = true;
  isLookupOpen = true;

  // ================= INIT =================
  connectedCallback() {
    getAllObjects().then((result) => {
      this.objectOptions = result.map((obj) => ({
        label: obj,
        value: obj,
      }));
    });
  }

  // ================= OBJECT CHANGE =================
  handleObjectChange(event) {
    this.selectedObject = event.detail.value;
    this.mappedFields = [];
    this.generatedJSON = null;

    getObjectFields({ objectName: this.selectedObject }).then((result) => {
      this.allFields = result;
    });

    getRelatedObjects({ objectName: this.selectedObject }).then((result) => {
      this.relatedData = result.map((obj) => ({
        name: obj,
        fields: [],
        isOpen: false,
      }));
    });
  }

  // ================= SEARCH =================
  handleSearch(event) {
    this.searchKey = event.target.value.toLowerCase();
  }

  filterList(list) {
    return list.filter((f) => f.label.toLowerCase().includes(this.searchKey));
  }

  // ================= FIELD TYPES =================
  get standardFields() {
    return this.allFields.filter(
      (f) => f.type !== "REFERENCE" && !f.apiName.endsWith("__c"),
    );
  }

  get customFields() {
    return this.allFields.filter((f) => f.apiName.endsWith("__c"));
  }

  get lookupFields() {
    return this.allFields.filter((f) => f.type === "REFERENCE");
  }

  // ================= VISIBLE LISTS (UPDATED - NO LIMIT) =================
  get visibleStandardFields() {
    return this.filterList(this.standardFields);
  }

  get visibleCustomFields() {
    return this.filterList(this.customFields);
  }

  get visibleLookupFields() {
    return this.filterList(this.lookupFields);
  }

  // ================= TOGGLES =================
  toggleStandard() {
    this.isStandardOpen = !this.isStandardOpen;
  }
  toggleCustom() {
    this.isCustomOpen = !this.isCustomOpen;
  }
  toggleLookup() {
    this.isLookupOpen = !this.isLookupOpen;
  }
  toggleRelated() {
    this.isRelatedOpen = !this.isRelatedOpen;
  }

  get standardIcon() {
    return this.isStandardOpen ? "▼" : "▶";
  }
  get customIcon() {
    return this.isCustomOpen ? "▼" : "▶";
  }
  get lookupIcon() {
    return this.isLookupOpen ? "▼" : "▶";
  }
  get relatedIcon() {
    return this.isRelatedOpen ? "▼" : "▶";
  }

  // ================= RELATED OBJECT CLICK =================
  handleRelatedClick(event) {
    const relatedObj = event.currentTarget.dataset.obj;
    let existing = this.relatedData.find((r) => r.name === relatedObj);
    if (!existing) return;

    if (existing.fields.length === 0) {
      getObjectFields({ objectName: relatedObj }).then((result) => {
        existing.fields = result;
        existing.isOpen = true;
        this.relatedData = [...this.relatedData];
      });
    } else {
      existing.isOpen = !existing.isOpen;
      this.relatedData = [...this.relatedData];
    }
  }

  // ================= DRAG =================
  handleDrag(event) {
    const api = event.target.dataset.api;
    const parent = event.target.dataset.parent || null;

    event.dataTransfer.setData(
      "text",
      JSON.stringify({
        apiName: api,
        parentObject: parent,
      }),
    );
  }

  allowDrop(event) {
    event.preventDefault();
  }

  // ================= DROP =================
  handleDrop(event) {
    event.preventDefault();

    const data = JSON.parse(event.dataTransfer.getData("text"));

    let fieldObj;

    if (!data.parentObject) {
      fieldObj = this.allFields.find((f) => f.apiName === data.apiName);
    } else {
      let rel = this.relatedData.find((r) => r.name === data.parentObject);
      if (rel) {
        fieldObj = rel.fields.find((f) => f.apiName === data.apiName);
      }
    }

    if (!fieldObj) return;

    const alreadyMapped = this.mappedFields.some(
      (f) =>
        f.apiName === fieldObj.apiName && f.parentObject === data.parentObject,
    );

    if (alreadyMapped) {
      this.showToast("Warning", "Field already mapped", "warning");
      return;
    }

    const mappedField = {
      label: fieldObj.label,
      apiName: fieldObj.apiName,
      type: fieldObj.type,
      parentObject: data.parentObject,
      uniqueKey: Date.now() + "_" + Math.random(),
    };

    this.mappedFields = [...this.mappedFields, mappedField];
  }

  // ================= DELETE =================
  handleDelete(event) {
    const key = event.currentTarget.dataset.key;
    this.mappedFields = this.mappedFields.filter((f) => f.uniqueKey !== key);
  }

  // ================= GENERATE JSON =================
  generateJSON() {
    if (!this.selectedObject) {
      this.showToast("Error", "Select object first", "error");
      return;
    }

    let output = {
      objectName: this.selectedObject,
      fields: [],
    };

    this.mappedFields.forEach((f) => {
      if (!f.parentObject) {
        output.fields.push({
          label: f.label,
          apiName: f.apiName,
          type: f.type,
        });
      } else {
        let existingRelated = output.fields.find(
          (field) => field.apiName === f.parentObject,
        );

        if (!existingRelated) {
          existingRelated = {
            label: f.parentObject,
            apiName: f.parentObject,
            type: "ChildRelationship",
            relatedObject: {
              objectName: f.parentObject,
              fields: [],
            },
          };

          output.fields.push(existingRelated);
        }

        existingRelated.relatedObject.fields.push({
          label: f.label,
          apiName: f.apiName,
          type: f.type,
        });
      }
    });

    this.generatedJSON = JSON.stringify(output, null, 2);
  }

  // ================= SAVE =================
  handleSave() {
    if (!this.generatedJSON) {
      this.showToast("Error", "Generate JSON first", "error");
      return;
    }

    saveMappingConfig({
      objectName: this.selectedObject,
      jsonData: this.generatedJSON,
    })
      .then(() => {
        this.showToast("Success", "Mapping saved successfully", "success");
      })
      .catch((error) => {
        this.showToast("Error", error.body.message, "error");
      });
  }

  // ================= CANCEL =================
  handleCancel() {
    this.mappedFields = [];
    this.generatedJSON = null;
  }

  // ================= TOAST =================
  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant,
      }),
    );
  }
}
