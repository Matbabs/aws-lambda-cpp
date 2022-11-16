import { Component, OnInit } from '@angular/core';
import * as JSZip from 'jszip';
import { AwsS3Service } from '../../services/aws-s3/aws-s3.service';
import { saveAs } from 'file-saver';
import { BehaviorSubject } from 'rxjs';
import { FileInput } from '../../models/fileInput';

@Component({
  selector: 'app-upload',
  templateUrl: './upload.component.html',
  styleUrls: ['./upload.component.css']
})
export class UploadComponent implements OnInit {

  isLoading: boolean;
  presignedUrlsDownload: string[];
  fileList!: FileList | null;
  uploadedFiles: BehaviorSubject<FileInput[]>;
  downloadFiles: BehaviorSubject<FileInput[]>;
  private zip: JSZip;

  constructor(private awsS3Service: AwsS3Service) {
    this.isLoading = false;
    this.presignedUrlsDownload = [];
    this.uploadedFiles = new BehaviorSubject<FileInput[]>([]);
    this.downloadFiles = new BehaviorSubject<FileInput[]>([]);
    this.zip = new JSZip();
  }

  ngOnInit(): void { }

  clickToAddFile() {
    document.getElementById("file-input")?.click()
  }

  handleUploadFiles(event: Event) {
    const element = event.currentTarget as HTMLInputElement;
    this.fileList = element.files;
    if (this.fileList && this.fileList.length > 0) {
      this.isLoading = true;
      this.presignedUrlsDownload = [];
      this.uploadedFiles.next([]);
      this.downloadFiles.next([]);
      this.uploadsFilesInS3();
    }
  }

  waitAllFilesUploadedInS3() {
    const subcription = this.uploadedFiles.subscribe((uploadedfiles) => {
      if (this.fileList && uploadedfiles.length === this.fileList.length) {
        this.awsS3Service.processFiles(this.uploadedFiles.value).subscribe((res: any) => {
          this.presignedUrlsDownload = res.presignedUrls
          this.downloadFilesFromS3()
          subcription.unsubscribe();
        });
      }
    })
  }

  uploadsFilesInS3() {
    if (this.fileList) {
      this.waitAllFilesUploadedInS3()
      Array.from(this.fileList).forEach((file: File) => {
        const fileReader = new FileReader()
        fileReader.onload = (e) => {
          const fileNameSplit = file.name.split(".");
          const inputFileName = file.name;
          const outputFileName = fileNameSplit[0] + "_processed." + fileNameSplit[1]
          const fileContent = fileReader.result;
          this.awsS3Service.getPresignedUrlUpload(inputFileName).subscribe((presignedUrlUpload: any) => {
            this.awsS3Service.uploadFile(presignedUrlUpload, inputFileName, fileContent as string).subscribe(() => {
              this.uploadedFiles.value.push({
                inputFileName,
                outputFileName
              });
              this.uploadedFiles.next(this.uploadedFiles.value);
            })
          })
        }
        fileReader.readAsText(file);
      });
    }
  }

  waitAllFilesDownloadFromS3() {
    const subcription = this.downloadFiles.subscribe((downloadFiles) => {
      if (this.fileList && downloadFiles.length === this.fileList.length) {
        this.isLoading = false;
        this.handleDownloadZip();
        subcription.unsubscribe();
      }
    })
  }

  downloadFilesFromS3() {
    if (this.fileList) {
      this.waitAllFilesDownloadFromS3();
      this.zip = new JSZip();
      for (let i = 0; i < this.presignedUrlsDownload.length; i++) {
        this.awsS3Service.downloadFile(this.presignedUrlsDownload[i]).subscribe({
          error: (res: any) => {
            const fileContent = res.error.text;
            this.zip.file(this.uploadedFiles.value[i].outputFileName, fileContent);
            this.downloadFiles.value.push(this.uploadedFiles.value[i]);
            this.downloadFiles.next(this.downloadFiles.value);
          }
        })
      }
    }
  }

  handleDownloadZip() {
    this.zip.generateAsync({ type: "blob" }).then(function (content) {
      saveAs(content, "processResult.zip");
    });
  }

}
